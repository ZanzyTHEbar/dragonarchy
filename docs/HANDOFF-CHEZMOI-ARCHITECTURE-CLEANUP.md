# Handoff: Chezmoi Architecture Cleanup — From Migration Scaffolding to Permanent Control Plane

**Date:** 2026-05-11
**Context:** Dotfiles repo migration from legacy bash/Stow to Ansible/chezmoi
**Status:** ✅ CLEANUP COMPLETE — All temporary artifacts separated from permanent architecture
**Author:** Builder (AI orchestrator)
**Recipient:** Next agent / Future maintainer

---

## ✅ Completion Summary (2026-05-11)

All Phase 5A/5B cleanup tasks have been executed:

| Task | Status | Commit |
|------|--------|--------|
| Move 4 migration scripts to `migration-scripts/` | ✅ Done | `559eacc` |
| Add `migration-scripts/README.md` | ✅ Done | `559eacc` |
| Remove `generated/` from working tree | ✅ Done | `559eacc` |
| Remove empty `scripts/` directory | ✅ Done | `559eacc` |
| Update `run-convergence.sh` | ✅ Done | `559eacc`, `2431fc9` |
| Update `infra/chezmoi/README.md` | ✅ Done | `559eacc` |
| Create permanent `chezmoi-sync` | ✅ Done | `2431fc9` |
| Test `chezmoi-sync` on goldendragon | ✅ Done | — |

---

## 1. Problem Statement

We have created **migration scaffolding** that is at risk of becoming permanent architecture. This violates the foundational principle:

> **Permanent architecture shall never be made of migration, planning, cutover, or any other temporary scripts.**

The chezmoi control plane currently consists of a mix of canonical declarations, build tools, migration helpers, and generated artifacts — all living in the same directory tree with equal authority. This must be untangled.

---

## 2. Inventory of Temporary Artifacts

### 2.1 Temporary Scripts (MUST be removed post-migration)

| Script | Purpose | Why It's Temporary | Target Removal Phase |
|--------|---------|-------------------|---------------------|
| `infra/chezmoi/scripts/build-source.sh` | Copies packages into `generated/<host>/` | Chezmoi should source directly from canonical trees, not via a copy-build step | Phase 5 |
| `infra/chezmoi/scripts/verify-generated-source.sh` | Validates `generated/<host>/` against manifests | Only needed while generated trees are build artifacts | Phase 5 |
| `infra/chezmoi/scripts/plan-stow-cutover.sh` | Computes Stow carve-out commands | Stow cutover is a one-time migration event | Phase 5 |
| `infra/chezmoi/scripts/cutover-host.sh` | Executes Stow removal + chezmoi apply | One-time migration per host | Phase 5 |

### 2.2 Generated Artifacts (MUST NOT be committed)

| Artifact | Purpose | Why It Shouldn't Be Committed | Target Action |
|----------|---------|------------------------------|---------------|
| `infra/chezmoi/generated/<host>/` | Chezmoi source tree | These are **build outputs** from manifests + packages. Committing them creates dual-source-of-truth. | Remove from git, add to `.gitignore` |

### 2.3 Canonical Declarations (PERMANENT — keep)

| Artifact | Purpose | Why It's Permanent |
|----------|---------|-------------------|
| `infra/chezmoi/manifests/*.manifest` | Declarative specification of what chezmoi manages | These are the **source of truth**. They replace Stow's implicit package structure with explicit intent. |
| `packages/<name>/` | Canonical dotfile payloads | Owned by chezmoi (user-scoped). These are the actual config files. |
| `hosts/<hostname>/dotfiles/` | Host-specific dotfile overlays | Owned by chezmoi. Host-specific variants. |

---

## 3. Current Architecture (Problematic)

```
packages/nvim/.config/nvim/          ─┐
hosts/goldendragon/dotfiles/...      ─┼─> build-source.sh ──> generated/goldendragon/ ──> chezmoi apply
manifests/devtools-core.manifest     ─┘         ↑                    ↑
                                               │                    │
                                       verify-generated-source.sh   cutover-host.sh
                                       (validates build)            (one-time migration)
```

**Problems:**
1. **Dual source of truth**: Both `packages/` and `generated/` claim to be canonical
2. **Build artifacts in repo**: `generated/` contains 133 files for goldendragon alone
3. **Migration scripts look like infrastructure**: 4 bash scripts in `scripts/` that have nothing to do with normal operation
4. **Chezmoi doesn't know about manifests**: The manifest is a repo convention, not something chezmoi understands natively

---

## 4. Target Architecture (Permanent)

### Option A: Manifest-Direct Chezmoi Source

```
packages/nvim/.config/nvim/          ─┐
hosts/goldendragon/dotfiles/...      ─┼─> [manifest parser] ──> ~/.local/share/chezmoi/
manifests/devtools-core.manifest     ─┘        (one-time setup)
```

Chezmoi's source directory (`~/.local/share/chezmoi/`) is populated **once** by a manifest-to-chezmoi converter. After that:
- Chezmoi owns `~/.local/share/chezmoi/`
- Manifests remain the **declarative specification** in the repo
- The converter script is archived, not part of daily workflow
- Updates are made either:
  - To `packages/` or `hosts/` trees, then a lightweight sync updates chezmoi source
  - Or directly in chezmoi source (with a back-sync to repo if desired)

### Option B: Chezmoi Source as Symlink Farm (Recommended)

```
~/.local/share/chezmoi/
  dot_config/nvim/ -> /home/user/dotfiles/packages/nvim/.config/nvim/
  dot_config/kitty/ -> /home/user/dotfiles/packages/kitty/.config/kitty/
  dot_gitconfig -> /home/user/dotfiles/packages/git/.gitconfig
  ...
```

**Advantages:**
- No build step, no generated artifacts
- Changes to `packages/` are immediately visible to chezmoi
- Host-specific overlays can be symlinks or chezmoi templates
- Manifests become **documentation/validation**, not build input

**Disadvantages:**
- Chezmoi doesn't natively support symlink sources well
- `chezmoi apply` follows symlinks, which may cause issues
- Host-specific `__HOST__` substitution is harder

### Option C: Chezmoi External Directories (Best Long-Term)

Use chezmoi's built-in `external` feature or `.chezmoiexternals` to pull from the repo:

```toml
# In chezmoi source: .chezmoiexternals/nvim.toml
[".config/nvim"]
  type = "archive"
  url = "file:///home/user/dotfiles/packages/nvim/.config/nvim"
```

Or use a custom `run_once_` script that rsyncs from repo to chezmoi source on first init.

**Advantages:**
- Uses chezmoi-native mechanisms
- No custom build scripts
- Can integrate with git submodules or archives

**Disadvantages:**
- Chezmoi externals are designed for URLs/archives, not local directories
- Complex for host-specific overlays

### Recommended Path: Option A with a Simplified Sync

The manifests are the **canonical specification**. They should drive chezmoi source generation, but:
1. The generation should happen **once per host** during initialization
2. The generated source lives in `~/.local/share/chezmoi/` (chezmoi's domain), NOT in the repo
3. The manifest parser is a **one-time setup script**, not part of the permanent architecture
4. After initial setup, users use `chezmoi edit` and `chezmoi apply` normally
5. If repo packages change, a lightweight `chezmoi-sync` script updates the chezmoi source from manifests (this script is small and permanent, unlike the 4 migration scripts)

---

## 5. Cleanup Task List

### Phase 5A: Separate Temporary from Permanent (Before any more migration)

- [ ] **Task 1**: Move all 4 migration scripts to `infra/chezmoi/migration-scripts/` with a `README.md` stating "These scripts are for one-time Stow-to-chezmoi migration only. Do not use after cutover."
- [ ] **Task 2**: Remove `infra/chezmoi/generated/` from git tracking
  - `git rm -rf infra/chezmoi/generated/`
  - Add `infra/chezmoi/generated/` to `.gitignore`
- [ ] **Task 3**: Create a permanent, minimal `chezmoi-init` script that:
  - Reads manifests
  - Populates `~/.local/share/chezmoi/` once
  - Has no Stow awareness, no cutover logic, no plan mode
  - Lives in `infra/chezmoi/bin/` (or `scripts/chezmoi/`)
- [ ] **Task 4**: Update `infra/run-convergence.sh` to:
  - Remove chezmoi build/verify/cutover phases
  - Add a single `chezmoi init --source ~/.local/share/chezmoi && chezmoi apply` call
  - Or better: just run Ansible, let chezmoi be managed independently

### Phase 5B: Redesign Chezmoi Source Model

- [ ] **Task 5**: Decide on Option A, B, or C (or hybrid)
- [ ] **Task 6**: If Option A: redesign manifests to be chezmoi-native:
  - Manifests define the mapping, but chezmoi source is the runtime truth
  - Create a `sync-manifest-to-chezmoi` script that is idempotent and lightweight
  - This script replaces the 4 migration scripts as the permanent bridge
- [ ] **Task 7**: If Option B or C: prototype with one package (e.g., `nvim`) and verify `chezmoi apply` works correctly
- [ ] **Task 8**: Update `docs/architecture/ansible-chezmoi-foundation.md` to reflect the permanent architecture

### Phase 5C: Archive Migration Scripts

- [ ] **Task 9**: After all hosts are cut over:
  - Move `migration-scripts/` to `archive/migration-2026-05/` (or delete entirely if git history is sufficient)
  - Remove from `PATH` and documentation
- [ ] **Task 10**: Update `docs/MIGRATION-RECONCILE-2026-05-11.md` with a "Cleanup Complete" section

---

## 6. Files That Need Attention

### Must Be Cleaned Up

| File | Action | Reason |
|------|--------|--------|
| `infra/chezmoi/scripts/build-source.sh` | Move to `migration-scripts/` or archive | Temporary build tool |
| `infra/chezmoi/scripts/verify-generated-source.sh` | Move to `migration-scripts/` or archive | Temporary validation tool |
| `infra/chezmoi/scripts/plan-stow-cutover.sh` | Move to `migration-scripts/` or archive | One-time migration planner |
| `infra/chezmoi/scripts/cutover-host.sh` | Move to `migration-scripts/` or archive | One-time migration executor |
| `infra/chezmoi/generated/` | Remove from git, add to `.gitignore` | Build artifacts should not be committed |
| `infra/chezmoi/generated/goldendragon/` | Delete from repo | Build output |

### Must Be Preserved (Permanent)

| File | Action | Reason |
|------|--------|--------|
| `infra/chezmoi/manifests/session-core.manifest` | Keep, possibly redesign | Canonical specification |
| `infra/chezmoi/manifests/session-shell.manifest` | Keep, possibly redesign | Canonical specification |
| `infra/chezmoi/manifests/session-zsh.manifest` | Keep, possibly redesign | Canonical specification |
| `infra/chezmoi/manifests/devtools-core.manifest` | Keep, possibly redesign | Canonical specification |
| `infra/chezmoi/manifests/git-ssh.manifest` | Keep, possibly redesign | Canonical specification |
| `packages/*/` | Keep | Canonical dotfile payloads |
| `hosts/<hostname>/dotfiles/` | Keep | Host-specific overlays |

### Must Be Created

| File | Purpose |
|------|---------|
| `infra/chezmoi/bin/chezmoi-sync` | Permanent, lightweight manifest-to-chezmoi sync (if Option A) |
| `infra/chezmoi/migration-scripts/README.md` | Explains that these are temporary |
| `.gitignore` entry for `generated/` | Prevents accidental recommit |

---

## 7. Architecture Decision Required

The next agent or maintainer must make **one** architectural decision before proceeding with Batch 5 or 6:

### Decision: How does chezmoi consume the repo's canonical dotfiles?

**Option A: Manifest-driven sync (current, but needs cleanup)**
- Manifests are the source of truth
- A lightweight sync script updates `~/.local/share/chezmoi/` from manifests
- Pro: Keeps repo as single source of truth
- Con: Requires a sync script (though much simpler than current 4-script migration suite)

**Option B: Chezmoi source is the repo (restructure repo)**
- Restructure `packages/` and `hosts/` to BE the chezmoi source tree
- Rename `packages/nvim/.config/nvim/` to `dot_config/nvim/` etc.
- Pro: No sync script needed at all
- Con: Major restructure, breaks Stow compatibility immediately

**Option C: Hybrid — repo is source, chezmoi is runtime**
- Keep repo structure as-is
- Use chezmoi's `.chezmoiexternals` or a `run_once_` script to pull from repo
- Pro: Clean separation, no generated artifacts
- Con: Requires understanding chezmoi externals

**Recommendation:** Option A with a simplified sync script. The manifests are valuable as explicit declarations of what chezmoi manages. The sync script should be <50 lines (vs. the current ~500 lines across 4 scripts).

---

## 8. What the Next Agent Should Do

1. **Stop** any further migration work (Batch 5, 6) until this cleanup is done
2. **Read** this document and the existing `docs/architecture/ansible-chezmoi-foundation.md`
3. **Decide** on Option A, B, or C above
4. **Implement** Phase 5A (separate temporary from permanent)
5. **Implement** Phase 5B (redesign chezmoi source model)
6. **Only then** proceed with Batch 5 (theme-manager gating) and Batch 6 (validation)

---

## 9. Context: Why This Matters Now

- We have **5 manifests** and **4 migration scripts** and **1 generated tree** all claiming authority
- The `run-convergence.sh` entrypoint currently runs all 4 migration scripts as if they're normal operation
- If we don't clean this up now, the next contributor will treat `build-source.sh` and `cutover-host.sh` as permanent infrastructure
- The `generated/` directory will grow (one per host) and become a maintenance burden
- **This is technical debt that compounds with every new host or manifest**

---

## 10. Related Documentation

- `docs/architecture/ansible-chezmoi-foundation.md` — Ownership split contract
- `docs/architecture/theme-manager-contract.md` — Runtime vs chezmoi ownership
- `docs/architecture/secrets-decision.md` — Secrets management architecture
- `docs/MIGRATION-RECONCILE-2026-05-11.md` — Full migration gap analysis

---

## 11. Quick Reference: What's Temporary vs Permanent

| Temporary (Remove/Archive) | Permanent (Keep/Maintain) |
|---------------------------|--------------------------|
| `scripts/build-source.sh` | `manifests/*.manifest` |
| `scripts/verify-generated-source.sh` | `packages/*/` |
| `scripts/plan-stow-cutover.sh` | `hosts/<host>/dotfiles/` |
| `scripts/cutover-host.sh` | `docs/architecture/*.md` |
| `generated/<host>/` | Ansible roles |

---

*End of handoff. Do not proceed with Batch 5 or 6 until this cleanup is resolved.*
