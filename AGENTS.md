# Repository priority: outcome parity and cohesive legacy replacement

User directive (2026-10-23): **"The highest priority is parity and removing legacy in totality BEFORE we add any new features."**

Owner clarification (2026-10-23): the Omarchy reconciliation, removal of cruft, corrective refactoring and cohesive desktop orchestration belong inside parity work. Preserve required outcomes, not obsolete implementations. All four existing hosts must function when the work is complete; their completion requirements remain binding.

Dragonarchy's product vision is reproducible, opinionated Linux host management: users compose reliable capabilities and personalize declared hosts. The current fleet is the acceptance baseline, not a reason to hard-code the product around one user's machines.

## Start and resume here

- Read [the managed lifecycle contract](docs/architecture/managed-lifecycle.md), especially **Retirement priority and session protocol** and **Parity and retirement closure ledger**, before choosing work.
- Finish supported outcome parity with explicit system, static-user and runtime owners; prove independent operation, then remove obsolete legacy provisioning, fallback dispatch, Stow ownership, migrations, CI dependencies and instructions. Ansible and chezmoi remain the established control plane unless evidence justifies a bounded replacement. Deprecation guards are not retirement.
- Cohesive command/session lifecycles, Quickshell/plugin integration, provider and ownership fixes, and removal of duplicate writers are in-scope parity work when tied to retained capabilities and the closure ledger. Do not port obsolete glue merely to replace it again. Inspect dependencies, preserve required behavior, establish cutover/recovery, then remove superseded paths.
- Unrelated new capabilities, platforms and speculative frameworks remain deferred. Existing dirty mobile/Wayle/Wleave/theme/opencode work is not blanket permission to extend it; preserve it without staging or reverting it. Changes in those areas need a specific parity/replacement rationale, not a filename-based prohibition or a feature-expansion loophole.
- Use the closure ledger to choose the first actionable gap or a bounded replacement that closes its dependencies. If blocked, advance another existing gap. Ask only for genuine product dispositions, changes to required outcomes or safety authorization; approved architectural improvements do not need repeated priority overrides.
- Capability parity is not blind file parity: retain supported behavior, explicitly retire unwanted behavior with the user, and do not port stale scripts, generated files, or broken absolute/package-relative links wholesale. No silent scope reduction.

## Evidence and handoff

- Reinspect source and Git state; the reconciliation snapshot at `068f0fa` is evidence, not timeless current status. Uncommitted additions are not the committed baseline.
- Use the lifecycle closure ledger as the current gap record; update it with exact changed paths, checks/results, unresolved decisions, and the next actionable step. Use existing task IDs where applicable; do not create competing plans or completion percentages.
- Do not mark parity complete from empty pending package tiers, role/manifest presence, static checks, or success on a legacy-seeded home. All four active hosts must be functional for their declared roles and retained capabilities: managed clean-home acceptance with Stow absent, cutover/recovery, repeat convergence and qualification of the final post-deletion revision. A working replacement desktop alone cannot certify servers, containers or hardware behavior.
- Bounded repository fixes, replacements and removal of proven obsolete source are authorized. Native qualification remains deferred and blocks completion. This does not authorize live host, SSH, native package, VM, service, boot, apply, cutover or destructive target operations. Get scoped approval before those operations. Do not commit, push, or open a PR unless requested.

## Preservation boundaries

- Active fleet: `firedragon`, `microdragon`, `opencode-runtime`, `ubuntu-mobile-dev`. Preserve archived `hosts/legacy/{dragon,goldendragon}`; they are not active qualification targets.
- Preserve canonical `rm-bg` behavior and unrelated user work; never broad-stage.
- Keep live payloads/helpers even if they originated under legacy: `packages/sddm`, `hosts/firedragon/etc`, theme-manager, hardware, Walker, icons, and bootloader helpers until dependency tracing proves a specific item obsolete. Do not delete `packages/`, `hosts/`, or `scripts/` wholesale.
- No invented providers, download URLs, versions, installers, or readiness claims. Every selected inventory package group is required; selected AUR/script tiers without a provider must fail closed. Host extras require explicit disposition, not quiet omission.
