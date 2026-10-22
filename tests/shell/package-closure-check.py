#!/usr/bin/env python3
"""Evaluate package task templates/assertions locally; never execute modules."""
import copy
import json
from pathlib import Path
import unittest

from ansible.parsing.dataloader import DataLoader
from ansible.template import Templar
try:
    from ansible.template import trust_as_template
except ImportError:  # Ansible before template trust tagging.
    def trust_as_template(value):
        return value


ROLE = Path(__file__).resolve().parents[2] / "infra/ansible/roles/packages"
LOADER = DataLoader()


def load(path):
    return LOADER.load_from_file(str(ROLE / path))


def plan(platform="arch", manager="pacman", package="git"):
    lists = {key: [] for key in ("pacman", "apt", "paru", "script")}
    lists[manager] = [package]
    return dict(manifest="/repo/scripts/install/deps.manifest.toml", platform=platform,
                host="closure-host", feature_csv="", requested_groups=["core_cli"],
                groups=[dict(manager=manager, group="core_cli", packages=[package],
                             tier={"pacman": "repo", "apt": "repo", "paru": "aur",
                                   "script": "script"}[manager])], by_manager=lists,
                ansible_install={key: lists[key] for key in ("pacman", "apt")},
                pending={key: lists[key] for key in ("paru", "script")})


class Closure(unittest.TestCase):
    def run_tasks(self, exported, **overrides):
        self.actions = []
        values = dict(load("defaults/main.yml"), inventory_hostname="closure-host",
                      host_platform_family=exported.get("platform", "arch"),
                      host_profile_packages=["core_cli"], playbook_dir="/repo/infra/ansible/playbooks")
        values.update(overrides)

        def render(value):
            if isinstance(value, str):
                return Templar(loader=LOADER, variables=values).template(trust_as_template(value))
            if isinstance(value, list):
                return [render(part) for part in value]
            if isinstance(value, dict):
                return {key: render(part) for key, part in value.items()}
            return value

        def condition(expr):
            templar = Templar(loader=LOADER, variables=values)
            if hasattr(templar, "evaluate_conditional"):
                return templar.evaluate_conditional(trust_as_template(expr))
            return templar.template("{{ " + expr + " }}")

        # Only this role's assertion/fact/loop subset; all module actions are spies.
        def tasks(filename):
            for task in load("tasks/" + filename):
                module = next(key for key in task if key.startswith("ansible.builtin."))
                args = task[module]
                items = render(task["loop"]) if "loop" in task else [None]
                for item in items:
                    values["item"] = item
                    when = task.get("when", [])
                    if isinstance(when, str):
                        when = [when]
                    if not all(condition(expr) for expr in when):
                        continue
                    if module.endswith(".import_tasks"):
                        tasks(args)
                    elif module.endswith(".assert"):
                        for expr in args["that"]:
                            if not condition(expr):
                                raise AssertionError(render(args.get("fail_msg", task["name"])))
                    elif module.endswith(".fail"):
                        raise AssertionError(render(args["msg"]))
                    elif module.endswith(".set_fact"):
                        values.update(render(args))
                    elif module.endswith(".command"):
                        self.actions.append("resolve")
                        values[task["register"]] = {"stdout": json.dumps(exported)}
                    elif module in ("ansible.builtin.package", "ansible.builtin.apt"):
                        self.actions.append((module, render(args["name"])))
                    elif module != "ansible.builtin.debug":
                        self.fail("Unexpected module: " + module)
        tasks("main.yml")

    def rejected(self, exported, *diagnostics, **overrides):
        with self.assertRaises(AssertionError) as error:
            self.run_tasks(exported, **overrides)
        self.assertTrue(all(action == "resolve" for action in self.actions), self.actions)
        for diagnostic in diagnostics:
            self.assertIn(diagnostic, str(error.exception))

    def test_pending_tiers_stop_before_native_actions(self):
        for tier, package in (("paru", "required-aur"), ("script", "required-vendor")):
            with self.subTest(tier=tier):
                exported = plan(manager=tier, package=package)
                exported["groups"].append(plan()["groups"][0])
                exported["by_manager"]["pacman"] = ["git"]
                exported["ansible_install"]["pacman"] = ["git"]
                self.rejected(exported, "closure-host", "core_cli", tier, package)

    def test_report_override_is_rejected_even_without_pending(self):
        for tier in ("paru", "script"):
            with self.subTest(tier=tier):
                self.rejected(plan(), "closure-host", "report", **{
                    "packages_pending_" + tier + "_policy": "report"})
                self.assertEqual(self.actions, [])

    def test_native_action_order_and_platform(self):
        for platform, manager, module in (("arch", "pacman", "package"),
                                          ("debian", "apt", "apt")):
            with self.subTest(platform=platform):
                self.run_tasks(plan(platform, manager))
                self.assertEqual(self.actions, ["resolve", ("ansible.builtin." + module, ["git"])])

    def test_malformed_plans_stop_before_install(self):
        paths = [(key,) for key in plan()]
        paths += [("ansible_install", key) for key in ("pacman", "apt")]
        paths += [("pending", key) for key in ("paru", "script")]
        paths += [("by_manager", key) for key in ("pacman", "apt", "paru", "script")]
        paths += [("groups", 0, key) for key in ("manager", "group", "tier", "packages")]
        for path in paths:
            for replacement in ("missing", None, 42, {}):
                with self.subTest(path=path, replacement=replacement):
                    exported = plan()
                    parent = exported
                    for key in path[:-1]:
                        parent = parent[key]
                    if replacement == "missing":
                        del parent[path[-1]]
                    else:
                        parent[path[-1]] = replacement
                    self.rejected(exported, "closure-host", "core_cli")

    def test_inconsistent_or_invalid_content_is_rejected(self):
        changes = [(("platform",), "debian"), (("host",), "other"),
                   (("requested_groups",), []), (("requested_groups",), ["other"]),
                   (("groups",), []), (("groups", 0, "manager"), "apt"),
                   (("groups", 0, "manager"), "unknown"), (("groups", 0, "tier"), "aur"),
                   (("groups", 0, "group"), "other"), (("groups", 0, "packages"), [""]),
                   (("groups", 0, "packages"), [1]), (("groups", 0, "packages"), ["   "]),
                   (("ansible_install", "pacman"), []),
                   (("by_manager", "pacman"), ["other"]), (("pending", "script"), ["hidden"])]
        for path, replacement in changes:
            with self.subTest(path=path, replacement=replacement):
                exported = copy.deepcopy(plan())
                parent = exported
                for key in path[:-1]:
                    parent = parent[key]
                parent[path[-1]] = replacement
                self.rejected(exported, "closure-host", "core_cli", host_platform_family="arch")

    def test_selected_group_without_packages_is_rejected(self):
        exported = plan()
        exported["groups"][0]["packages"] = []
        exported["by_manager"]["pacman"] = []
        exported["ansible_install"]["pacman"] = []
        self.rejected(exported, "closure-host", "core_cli")

    def test_resolver_is_controller_local_and_runs_in_check_mode(self):
        task = next(task for task in load("tasks/resolve.yml")
                    if task["name"].startswith("Resolve package plan"))
        self.assertIs(task.get("become"), False)
        self.assertIs(task.get("check_mode"), False)
        self.assertIn("--no-bootstrap", task["ansible.builtin.command"]["argv"])


if __name__ == "__main__":
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Closure))
    if not result.wasSuccessful():
        raise SystemExit(1)
    print("PACKAGE_CLOSURE_PASSED")
