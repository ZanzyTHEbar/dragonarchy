#!/usr/bin/env python3
"""Local snapshot/restore for the mobile profile's literal file mappings only."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import tempfile

REPO = Path(__file__).resolve().parents[2]
LIMIT = 1024 * 1024


def managed_paths():
    # Deliberately not a general chezmoi decoder: reject unsupported mapping forms.
    paths = []
    for name in ("common", "mobile"):
        manifest = REPO / f"infra/chezmoi/manifests/mobile/{name}.manifest"
        for line in manifest.read_text().splitlines():
            if not line or line.startswith("#"):
                continue
            mode, source, destination = line.split("|")
            source_path = PurePosixPath(source)
            if (mode != "required" or not destination.startswith("dot_config/")
                    or source_path.is_absolute() or ".." in source_path.parts
                    or not (REPO / source).is_file()
                    or destination.endswith(".tmpl")):
                raise ValueError("Snapshot supports only required literal dot_config file mappings")
            relative = ".config/" + destination.removeprefix("dot_config/")
            parts = PurePosixPath(relative).parts
            if (".." in parts or PurePosixPath(relative).as_posix() != relative
                    or not relative.startswith((".config/omalauncher/", ".config/omarchy/themes/"))
                    or relative in paths):
                raise ValueError(f"Invalid or duplicate managed path: {relative}")
            paths.append(relative)
    if not paths:
        raise ValueError("Empty mobile inventory")
    return paths


def no_symlink_ancestors(path):
    for parent in (path, *path.parents):
        if parent.is_symlink():
            raise ValueError(f"Symlink ancestor is not allowed: {parent}")


def target(home, relative):
    path = home / relative
    no_symlink_ancestors(path.parent)
    return path


def capture(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return {"kind": "absent"}
    if stat.S_ISLNK(info.st_mode):
        return {"kind": "symlink", "target": os.readlink(path)}
    if not stat.S_ISREG(info.st_mode) or info.st_size > LIMIT:
        raise ValueError(f"Expected a regular file <= 1 MiB or symlink: {path}")
    content = path.read_bytes()
    return {"kind": "file", "mode": stat.S_IMODE(info.st_mode),
            "content": base64.b64encode(content).decode(),
            "sha256": hashlib.sha256(content).hexdigest()}


def validate_entry(entry):
    kind = entry.get("kind")
    if kind == "absent" and set(entry) == {"kind"}:
        return
    if kind == "symlink" and set(entry) == {"kind", "target"}:
        if isinstance(entry["target"], str) and entry["target"] and "\0" not in entry["target"]:
            return
    if kind == "file" and set(entry) == {"kind", "mode", "content", "sha256"}:
        content = base64.b64decode(entry["content"], validate=True)
        if (type(entry["mode"]) is int and 0 <= entry["mode"] <= 0o777
                and len(content) <= LIMIT and hashlib.sha256(content).hexdigest() == entry["sha256"]):
            return
    raise ValueError("Invalid snapshot entry or content hash")


def restore_file(path, entry):
    if entry["kind"] == "absent":
        path.unlink(missing_ok=True)
        return
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Each replacement is atomic; an interrupted multi-file restore can be rerun.
    fd, temporary = tempfile.mkstemp(prefix=".dragonarchy-restore-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            if entry["kind"] == "file":
                output.write(base64.b64decode(entry["content"], validate=True))
                output.flush()
                os.fchmod(output.fileno(), entry["mode"])
                os.fsync(output.fileno())
        if entry["kind"] == "symlink":
            os.unlink(temporary)
            os.symlink(entry["target"], temporary)
        os.replace(temporary, path)
    finally:
        if os.path.lexists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("snapshot", "restore"))
    parser.add_argument("--home", type=Path, required=True, help="Explicit Omalauncher guest home")
    parser.add_argument("--backup", type=Path, required=True, help="Private JSON backup outside guest home")
    parser.add_argument("--mode", choices=("plan", "apply"), default="plan", help="Restore only; default is non-mutating")
    args = parser.parse_args()
    home, backup = args.home, args.backup
    for path in (home, backup):
        if not path.is_absolute() or ".." in path.parts:
            raise ValueError("--home and --backup must be absolute paths without traversal")
    no_symlink_ancestors(home)
    no_symlink_ancestors(backup)
    if not home.is_dir() or home == Path("/") or backup.is_relative_to(home):
        raise ValueError("Expected an existing guest home and backup outside that home")
    if not backup.parent.is_dir() or stat.S_IMODE(backup.parent.stat().st_mode) & 0o077:
        raise ValueError("Backup parent must already exist and be private (mode 0700)")
    paths = managed_paths()
    current = {relative: capture(target(home, relative)) for relative in paths}
    if args.operation == "snapshot":
        document = {"version": 1, "target": "poco-x3-pro", "runtime": "omalauncher",
                    "home": str(home), "files": current}
        for entry in current.values():
            validate_entry(entry)
        # Never overwrite a previous backup; contents are sensitive, even for config.
        fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as output:
            json.dump(document, output)
            output.flush()
            os.fsync(output.fileno())
        print(json.dumps({"status": "saved", "backup": str(backup), "files": len(paths)}))
        return
    if not backup.is_file() or backup.stat().st_size > 8 * LIMIT:
        raise ValueError("Invalid or oversized snapshot file")
    if stat.S_IMODE(backup.stat().st_mode) & 0o077:
        raise ValueError("Snapshot must not be group/world accessible")
    document = json.loads(backup.read_text())
    if (document.get("version") != 1 or document.get("home") != str(home)
            or document.get("target") != "poco-x3-pro" or document.get("runtime") != "omalauncher"
            or set(document["files"]) != set(paths)):
        raise ValueError("Snapshot identity/inventory mismatch")
    for entry in document["files"].values():
        validate_entry(entry)
    changed = [relative for relative in paths if current[relative] != document["files"][relative]]
    plan = [{"path": relative, "action": "remove" if document["files"][relative]["kind"] == "absent"
             else "restore"} for relative in changed]
    if args.mode == "apply":
        for relative in changed:
            path = target(home, relative)
            if capture(path) != current[relative]:
                raise ValueError(f"File changed during restore: {relative}")
            restore_file(path, document["files"][relative])
        if any(capture(target(home, relative)) != document["files"][relative] for relative in paths):
            raise ValueError("Restore verification failed")
    print(json.dumps({"status": "restored" if args.mode == "apply" else "plan", "changes": plan}))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        raise SystemExit(f"Mobile file operation failed: {error}")
