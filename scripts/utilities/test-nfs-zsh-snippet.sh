#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SNIPPET="$ROOT_DIR/packages/zsh/.config/zsh/hosts/shared/nfs-common.zsh"

if [[ ! -r "$SNIPPET" ]]; then
  echo "FAIL: snippet not readable: $SNIPPET" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

fstab="$workdir/fstab"
mountinfo="$workdir/mountinfo"
mkdir -p "$workdir/mnt"

# --- Case 1: managed fstab present, but nothing mounted -> should not add PATH entries
cat >"$fstab" <<'EOF'
# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT
server:/export/common /tmp/SHOULD_NOT_BE_USED nfs4 rw 0 0
server:/export/common /mnt/common nfs4 rw 0 0
server:/export/data /mnt/dragonnet nfs4 rw 0 0
# END NFS-AUTOMOUNT MANAGED SECTION
EOF

: >"$mountinfo"

out1="$workdir/out1.txt"
env -i \
  PATH=/usr/bin:/bin \
  NFS_TOOLING_FSTAB="$fstab" \
  NFS_TOOLING_MOUNTINFO="$mountinfo" \
  NFS_TOOLING_MOUNT_PREFIX="$workdir/mnt/" \
  zsh -f -c "unset ANDROID_SDK_ROOT ANDROID_HOME; source '$SNIPPET'; nfs_maybe_enable_tooling; print -r -- \"PATH=\$PATH\"; print -r -- \"ANDROID_SDK_ROOT=\${ANDROID_SDK_ROOT-}\"" >"$out1"

if grep -q "/mnt/common/bin" "$out1"; then
  echo "FAIL(case1): PATH unexpectedly contains /mnt/common/bin" >&2
  cat "$out1" >&2
  exit 1
fi

echo "PASS(case1): no PATH changes when nothing mounted"

# --- Case 1b: automount present as autofs -> should still NOT add PATH entries
cat >"$mountinfo" <<EOF
36 25 0:32 / $workdir/mnt/common rw,relatime - autofs systemd-1 rw
EOF

out1b="$workdir/out1b.txt"
env -i \
  PATH=/usr/bin:/bin \
  NFS_TOOLING_FSTAB="$fstab" \
  NFS_TOOLING_MOUNTINFO="$mountinfo" \
  NFS_TOOLING_MOUNT_PREFIX="$workdir/mnt/" \
  zsh -f -c "unset ANDROID_SDK_ROOT ANDROID_HOME; source '$SNIPPET'; nfs_maybe_enable_tooling; print -r -- \"PATH=\$PATH\"; print -r -- \"ANDROID_SDK_ROOT=\${ANDROID_SDK_ROOT-}\"" >"$out1b"

if grep -q "$workdir/mnt/common/bin" "$out1b"; then
  echo "FAIL(case1b): PATH unexpectedly contains common/bin for autofs" >&2
  cat "$out1b" >&2
  exit 1
fi

if grep -q "ANDROID_SDK_ROOT=" "$out1b" && ! grep -q "ANDROID_SDK_ROOT=$" "$out1b"; then
  echo "FAIL(case1b): ANDROID_SDK_ROOT unexpectedly set for autofs" >&2
  cat "$out1b" >&2
  exit 1
fi

echo "PASS(case1b): autofs does not trigger tooling enablement"

# --- Case 2: managed fstab present, only dragonnet is mounted and has tooling
# Rewrite managed fstab to point at our temp mount root.
cat >"$fstab" <<EOF
# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT
server:/export/common $workdir/mnt/common nfs4 rw 0 0
server:/export/data $workdir/mnt/dragonnet nfs4 rw 0 0
# END NFS-AUTOMOUNT MANAGED SECTION
EOF

# Create fake mount tree
mkdir -p "$workdir/mnt/dragonnet/bin" \
         "$workdir/mnt/dragonnet/bin/flutter/bin" \
         "$workdir/mnt/dragonnet/bin/cmdline-tools/bin"

cat >"$mountinfo" <<EOF
36 25 0:32 / $workdir/mnt/dragonnet rw,relatime - nfs4 server:/export/data rw
EOF

out2="$workdir/out2.txt"
env -i \
  PATH=/usr/bin:/bin \
  NFS_TOOLING_FSTAB="$fstab" \
  NFS_TOOLING_MOUNTINFO="$mountinfo" \
  NFS_TOOLING_MOUNT_PREFIX="$workdir/mnt/" \
  zsh -f -c "unset ANDROID_SDK_ROOT ANDROID_HOME; source '$SNIPPET'; nfs_maybe_enable_tooling; print -r -- \"PATH=\$PATH\"" >"$out2"

if ! grep -q "$workdir/mnt/dragonnet/bin" "$out2"; then
  echo "FAIL(case2): PATH missing dragonnet/bin" >&2
  cat "$out2" >&2
  exit 1
fi

echo "PASS(case2): enables tooling paths for mounted dataset"

# --- Case 3: fallback mode (no managed section), mounted NFS under custom prefix
# Remove managed markers so fstab yields no mountpoints
: >"$fstab"

mkdir -p "$workdir/mnt/random/bin" "$workdir/mnt/random/bin/platform-tools" "$workdir/mnt/random/bin/cmdline-tools/latest/bin"
cat >"$mountinfo" <<EOF
40 25 0:33 / $workdir/mnt/random rw,relatime - nfs4 server:/export/random rw
EOF

out3="$workdir/out3.txt"
env -i \
  PATH=/usr/bin:/bin \
  NFS_TOOLING_FSTAB="$fstab" \
  NFS_TOOLING_MOUNTINFO="$mountinfo" \
  NFS_TOOLING_MOUNT_PREFIX="$workdir/mnt/" \
  zsh -f -c "unset ANDROID_SDK_ROOT ANDROID_HOME; source '$SNIPPET'; nfs_maybe_enable_tooling; print -r -- \"PATH=\$PATH\"; print -r -- \"ANDROID_SDK_ROOT=\${ANDROID_SDK_ROOT-}\"" >"$out3"

if ! grep -q "$workdir/mnt/random/bin" "$out3"; then
  echo "FAIL(case3): fallback PATH missing random/bin" >&2
  cat "$out3" >&2
  exit 1
fi

if ! grep -q "ANDROID_SDK_ROOT=$workdir/mnt/random/bin" "$out3"; then
  echo "FAIL(case3): ANDROID_SDK_ROOT not set from mounted SDK-like tree" >&2
  cat "$out3" >&2
  exit 1
fi

echo "PASS(case3): fallback detects mounted NFS + sets Android vars when appropriate"

echo "ALL PASS"
