See the full handoff in the pangolin-vpn checkout:

~/Documents/local/pangolin-vpn/HANDOFF.md

(Or /home/daofficialwizard/Documents/local/pangolin-vpn/HANDOFF.md)

This covers the intertwined issues: Pangolin VPN client routes/NFS not working on goldendragon + repeated PAM/sudo breakage from fingerprint auth setup.

Key: Use the structure and scripts here (FINGERPRINT.md, scripts/fingerprint/, setup.sh as ref only -- Ansible preferred) for any PAM/fprintd fixes. Do not use ad-hoc or history scripts that mangle /etc/pam.d/sudo.

After PAM fixed (via proper dotfiles method + pkexec for root), re-run pangolin-vpn recovery.

Full details + steps in the linked HANDOFF.md.

2026-06-05 update: recovery pass completed PAM/faillock reset, fprintd USB reset, Pangolin route-helper fix, route/readiness/NFS verification. See the Recovery Update section in the full handoff.
