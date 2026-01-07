# Shared host snippet: NFS-backed tooling (safe with systemd automount)
#
# Goal:
# - Never touch an automount mountpoint unless it's already mounted.
# - When mounts *are* active, opportunistically add common tooling paths.
# - Detect mounts created by `nfs.sh` (managed /etc/fstab section), but keep a
#   safe fallback for other NFS mounts.

_nfs_tooling_is_mount_active() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local mount_point="${1-}"
    local mountinfo_path="${NFS_TOOLING_MOUNTINFO:-/proc/self/mountinfo}"

    [[ -r "$mountinfo_path" ]] || return 1

    # IMPORTANT:
    # With systemd automount, the mountpoint often exists as an `autofs` mount even
    # before the real NFS mount is established. Touching paths under it can trigger
    # the mount (and hang if the server is unreachable). Only treat the mount as
    # active when the fstype is actually `nfs*`.
    awk -v mp="$mount_point" '
        BEGIN { found = 0; is_nfs = 0 }
        $5 == mp {
            found = 1
            fstype = ""
            for (i = 1; i <= NF; i++) {
                if ($i == "-") {
                    fstype = $(i+1)
                    break
                }
            }
            if (fstype ~ /^nfs/) is_nfs = 1
            exit
        }
        END { exit (found && is_nfs) ? 0 : 1 }
    ' "$mountinfo_path"
}

_nfs_tooling_pathappend_literal() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local arg
    for arg in "$@"; do
        [[ ":$PATH:" == *":$arg:"* ]] && continue
        PATH="${PATH:+"$PATH:"}$arg"
    done
}

_nfs_tooling_get_managed_mount_points() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local fstab="${NFS_TOOLING_FSTAB:-/etc/fstab}"
    local begin='# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT'
    local end='# END NFS-AUTOMOUNT MANAGED SECTION'

    [[ -r "$fstab" ]] || return 1

    # Extract mount points from the managed section only.
    # fstab columns: <src> <mount> <type> <opts> <dump> <pass>
    awk -v begin="$begin" -v end="$end" '
        $0 == begin { in=1; next }
        $0 == end { in=0; exit }
        in && $0 !~ /^#/ && NF >= 3 && ($3 ~ /^nfs/ || $3 == "nfs4") { print $2 }
    ' "$fstab"
}

_nfs_tooling_get_mounted_nfs_under_mnt() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local mountinfo_path="${NFS_TOOLING_MOUNTINFO:-/proc/self/mountinfo}"
    local mount_prefix="${NFS_TOOLING_MOUNT_PREFIX:-/mnt/}"

    [[ -r "$mountinfo_path" ]] || return 1

    # mount point is $5; fs type is after the " - " separator as the first field
    awk -v prefix="$mount_prefix" '
        {
            mp = $5
            for (i = 1; i <= NF; i++) {
                if ($i == "-") {
                    fstype = $(i+1)
                    break
                }
            }
            if (index(mp, prefix) == 1 && fstype ~ /^nfs/) print mp
        }
    ' "$mountinfo_path"
}

typeset -gA _nfs_tooling_enabled_for

_nfs_tooling_enable_for_mount() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local mount_point="${1-}"
    local base_bin="$mount_point/bin"

    [[ -n "$mount_point" ]] || return 0
    [[ -n "${_nfs_tooling_enabled_for[$mount_point]-}" ]] && return 0

    # Only safe to probe inside the mount once it's actually mounted.
    _nfs_tooling_is_mount_active "$mount_point" || return 0

    # Common conventions used by this dotfiles repo
    [[ -d "$base_bin" ]] && _nfs_tooling_pathappend_literal "$base_bin"
    [[ -d "$base_bin/flutter/bin" ]] && _nfs_tooling_pathappend_literal "$base_bin/flutter/bin"
    [[ -d "$base_bin/cmdline-tools/bin" ]] && _nfs_tooling_pathappend_literal "$base_bin/cmdline-tools/bin"

    # Android tooling: only set if the mount actually looks like an SDK root.
    if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
        if [[ -d "$base_bin/platform-tools" || -d "$base_bin/cmdline-tools" ]]; then
            export ANDROID_SDK_ROOT="$base_bin"
            export ANDROID_HOME="$ANDROID_SDK_ROOT"
            [[ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin" ]] && _nfs_tooling_pathappend_literal "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
            [[ -d "$ANDROID_SDK_ROOT/platform-tools" ]] && _nfs_tooling_pathappend_literal "$ANDROID_SDK_ROOT/platform-tools"
        fi
    fi

    _nfs_tooling_enabled_for[$mount_point]=1
}

nfs_maybe_enable_tooling() {
    emulate -L zsh
    setopt no_unset 2>/dev/null || true

    local -a mount_points

    # Prefer the mount points created via nfs.sh (even if currently unmounted).
    mount_points=( ${(@f)$(_nfs_tooling_get_managed_mount_points 2>/dev/null)} )

    # Fallback: if no managed section exists, just use currently mounted NFS under /mnt.
    if (( ${#mount_points[@]} == 0 )); then
        mount_points=( ${(@f)$(_nfs_tooling_get_mounted_nfs_under_mnt 2>/dev/null)} )
    fi

    local mp
    for mp in "${mount_points[@]}"; do
        _nfs_tooling_enable_for_mount "$mp"
    done
}

# Run once now (non-blocking) and then re-check each prompt until mounts come online.
nfs_maybe_enable_tooling 2>/dev/null || true
if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook 2>/dev/null || true
    (( $+functions[add-zsh-hook] )) && add-zsh-hook precmd nfs_maybe_enable_tooling
fi
