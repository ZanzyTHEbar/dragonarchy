#!/usr/bin/env python3
"""Shared inventory target-tuple resolver and validator for install and run-playbook.sh."""

import json
import os
import sys


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def required_string(value: object, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} must be a non-empty inventory field")
    return value


def canonical_path(value: object, label: str, check_filesystem: bool = True) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} must be a non-empty inventory field")
    if not value.startswith("/"):
        fail(f"{label} must be an absolute path")
    if "\0" in value:
        fail(f"{label} contains a NUL byte")
    if any(component in {".", ".."} for component in value.split("/")):
        fail(f"{label} contains dot path components")
    if value.startswith("//") or os.path.normpath(value) != value:
        fail(f"{label} is not lexically canonical")
    if check_filesystem and os.path.realpath(value) != value:
        fail(f"{label} resolves through a symlink")
    return value


def normalize_connection(value: object, label: str) -> str:
    text = required_string(value, label)
    if text == "local":
        return "local"
    if text in {"ssh", "remote-ssh"}:
        return "ssh"
    fail(f"{label} has an unsupported value: {text}")
    raise AssertionError("unreachable")


def load_inventory(err_message: str) -> dict:
    try:
        data = json.loads(os.environ["INVENTORY_JSON"])
    except (KeyError, json.JSONDecodeError) as error:
        fail(err_message.format(error=error))
    if not isinstance(data, dict):
        fail(err_message)
    return data


def resolve_mode(requested_user: str) -> None:
    inventory = load_inventory("inventory output is not valid JSON: {error}")
    users = inventory.get("managed_users")
    if not isinstance(users, list) or not users:
        fail("managed_users must be a non-empty list")
    if not requested_user:
        fail("an explicit --user selection is required for managed_users")

    selected = [u for u in users if isinstance(u, dict) and u.get("name") == requested_user]
    if len(selected) != 1:
        fail(f"managed user selection is not unique: {requested_user}")
    if any(not isinstance(u, dict) or not isinstance(u.get("name"), str) or not u["name"].strip() for u in users):
        fail("every managed user must have a non-empty name")

    profile = required_string(inventory.get("target_profile"), "target_profile")
    target_connection = normalize_connection(inventory.get("target_connection"), "target_connection")
    check_filesystem = target_connection == "local"
    platform_connection_mode = required_string(inventory.get("platform_connection_mode"), "platform_connection_mode")
    target_home = canonical_path(inventory.get("target_home"), "target_home", check_filesystem)
    target_source = canonical_path(inventory.get("target_source"), "target_source", check_filesystem)

    policy_fields = [
        "platform_local_connection_policy",
        "platform_container_policy",
        "platform_remote_connection_policy",
        "platform_container_identity",
        "platform_controller_home_policy",
        "platform_unsupported_combination_policy",
        "platform_generic_family_fallback",
    ]
    policies = {field: required_string(inventory.get(field), field) for field in policy_fields}
    expected = {
        "local": "forbidden" if profile == "remote-host" else "required",
        "container": "required" if profile == "container" else "forbidden",
        "remote": "required" if profile == "remote-host" else "forbidden",
        "identity": "declared-local-container" if profile == "container" else "not-applicable",
    }

    if profile not in {"local-profile", "remote-host", "container"}:
        fail(f"target_profile has an unsupported value: {profile}")
    if {"local": "local", "remote-ssh": "ssh"}.get(platform_connection_mode) != target_connection:
        fail("target connection and platform connection mode drift")
    if target_connection != ("ssh" if profile == "remote-host" else "local"):
        fail("target profile and target connection drift")
    if (
        policies["platform_local_connection_policy"] != expected["local"]
        or policies["platform_container_policy"] != expected["container"]
        or policies["platform_remote_connection_policy"] != expected["remote"]
        or policies["platform_container_identity"] != expected["identity"]
        or policies["platform_controller_home_policy"] != "forbidden"
        or policies["platform_unsupported_combination_policy"] != "reject"
        or policies["platform_generic_family_fallback"] != "forbidden"
    ):
        fail("target profile and platform policy drift")

    user = selected[0]
    home = canonical_path(user.get("home"), f"managed_users.{user['name']}.home", check_filesystem)
    source = canonical_path(user.get("chezmoi_source"), f"managed_users.{user['name']}.chezmoi_source", check_filesystem)
    if home != target_home or source != target_source:
        fail("managed user home/source does not match the inventory target tuple")
    if target_home in {"/", "/root"} or target_source != f"{target_home}/.local/share/chezmoi":
        fail("inventory target home/source binding is unsafe or drifted")
    if "ansible_connection" in inventory and normalize_connection(inventory["ansible_connection"], "ansible_connection") != target_connection:
        fail("ansible connection and target connection drift")

    fields = [profile, target_connection, user["name"], home, source]
    if any(not isinstance(f, str) or "\t" in f or "\n" in f for f in fields):
        fail("inventory target tuple contains an invalid field")
    print("\t".join(fields))


def validate_site_mode() -> None:
    inventory = load_inventory("site target inventory is not valid JSON")
    for field in ("target_profile", "target_connection", "target_home", "target_source", "managed_users"):
        if field not in inventory:
            fail(f"inventory is missing {field}")
    check_filesystem = normalize_connection(inventory["target_connection"], "target_connection") == "local"

    tuple_fields = {
        "target_profile": os.environ.get("TUPLE_PROFILE", ""),
        "target_user": os.environ.get("TUPLE_USER", ""),
        "target_home": canonical_path(os.environ.get("TUPLE_HOME", ""), "target_home", check_filesystem),
        "target_source": canonical_path(os.environ.get("TUPLE_SOURCE", ""), "target_source", check_filesystem),
        "target_connection": os.environ.get("TUPLE_CONNECTION", ""),
    }
    if any(not isinstance(v, str) or not v for v in tuple_fields.values()):
        fail("site target tuple fields must be non-empty")

    if not isinstance(inventory["managed_users"], list):
        fail("inventory managed_users must be a list")
    inventory_home = canonical_path(inventory["target_home"], "inventory target_home", check_filesystem)
    inventory_source = canonical_path(inventory["target_source"], "inventory target_source", check_filesystem)
    if tuple_fields["target_home"] in {"/", "/root"} or inventory_home in {"/", "/root"}:
        fail("target home is unsafe")
    if inventory_source != f"{inventory_home}/.local/share/chezmoi":
        fail("inventory target source does not match target home")

    selected = [
        u for u in inventory["managed_users"]
        if isinstance(u, dict) and u.get("name") == tuple_fields["target_user"]
    ]
    if len(selected) != 1:
        fail(f"selected managed user is not unique: {tuple_fields['target_user']}")
    if tuple_fields["target_profile"] != inventory["target_profile"]:
        fail("target profile does not match inventory")
    if tuple_fields["target_connection"] != inventory["target_connection"]:
        fail("target connection does not match inventory")

    user = selected[0]
    user_home = canonical_path(user.get("home"), "managed user home", check_filesystem)
    user_source = canonical_path(user.get("chezmoi_source"), "managed user source", check_filesystem)
    if user_home != tuple_fields["target_home"] or inventory_home != tuple_fields["target_home"]:
        fail("target home does not match inventory")
    if user_source != tuple_fields["target_source"] or inventory_source != tuple_fields["target_source"]:
        fail("target source does not match inventory")
    if tuple_fields["target_source"] != f"{tuple_fields['target_home']}/.local/share/chezmoi":
        fail("target source does not match target home")


def connection_mode() -> None:
    try:
        inventory = json.loads(os.environ["INVENTORY_JSON"])
    except (KeyError, json.JSONDecodeError):
        raise SystemExit(2)
    connection = inventory.get("target_connection") if isinstance(inventory, dict) else None
    if connection == "local":
        print("local")
    elif connection in {"ssh", "remote-ssh"}:
        print("ssh")
    else:
        raise SystemExit(2)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "resolve":
        resolve_mode(sys.argv[2] if len(sys.argv) > 2 else "")
    elif mode == "validate-site":
        validate_site_mode()
    elif mode == "connection":
        connection_mode()
    elif mode == "check-paths" and len(sys.argv) == 4:
        home = canonical_path(sys.argv[2], "target_home")
        source = canonical_path(sys.argv[3], "target_source")
        if home in {"/", "/root"} or source != f"{home}/.local/share/chezmoi":
            fail("target home/source binding is unsafe or drifted")
        for path in (home, source):
            current = path
            while current != "/":
                if os.path.exists(current) and not os.path.isdir(current):
                    fail(f"target path is not a directory: {current}")
                current = os.path.dirname(current)
    else:
        fail(f"unknown mode: {mode}")
