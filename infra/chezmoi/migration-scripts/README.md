# Chezmoi Migration Scripts (TEMPORARY)

**Status:** Migration-only — not part of permanent architecture  
**Purpose:** One-time Stow-to-chezmoi cutover tooling  
**Removal Target:** After all hosts have completed cutover

---

## Scripts

| Script | Purpose | Lifecycle |
|--------|---------|-----------|
| `build-source.sh` | Copies `packages/` and `hosts/` into `generated/<host>/` | Temporary — chezmoi should source directly from canonical trees |
| `verify-generated-source.sh` | Validates `generated/<host>/` against manifests | Temporary — only needed while generated trees are build artifacts |
| `plan-stow-cutover.sh` | Computes Stow carve-out commands for migration | Temporary — one-time migration planner |
| `cutover-host.sh` | Executes Stow removal + chezmoi apply | Temporary — one-time migration per host |

## Why These Are Temporary

These scripts were created during the migration from GNU Stow to chezmoi. They solve a **transient problem** (moving from one dotfile manager to another) and should not be treated as permanent infrastructure.

### Architectural Violations

1. **Build artifacts in repo**: `generated/<host>/` directories are outputs, not sources
2. **Dual source of truth**: Both `packages/` and `generated/` claim authority
3. **Migration scripts as infrastructure**: 4 bash scripts for a one-time event

### Permanent Replacement

See `docs/HANDOFF-CHEZMOI-ARCHITECTURE-CLEANUP.md` for the target architecture.

The permanent chezmoi sync mechanism lives in `../bin/chezmoi-sync` (or is handled by chezmoi natively via `.chezmoiexternals` / direct source management).

## Usage (During Migration Only)

```bash
# Build generated source for a host
./migration-scripts/build-source.sh --host goldendragon

# Verify the generated tree
./migration-scripts/verify-generated-source.sh --host goldendragon

# Plan Stow carve-out
./migration-scripts/plan-stow-cutover.sh --host goldendragon

# Execute cutover (dry-run by default)
./migration-scripts/cutover-host.sh --host goldendragon
./migration-scripts/cutover-host.sh --host goldendragon --execute
```

## Do Not Use After Cutover

Once a host has been cut over to chezmoi:
- Use `chezmoi edit` and `chezmoi apply` for normal operations
- Use `../bin/chezmoi-sync` (if implemented) to sync from repo manifests
- Do not re-run these migration scripts

## Archive Plan

After all hosts (dragon, firedragon, goldendragon, microdragon) have completed cutover:
1. Move this directory to `archive/migration-2026-05/` or delete entirely
2. Remove references from `infra/run-convergence.sh`
3. Update documentation

---

*Created: 2026-05-11*  
*Expected removal: 2026-Q3*
