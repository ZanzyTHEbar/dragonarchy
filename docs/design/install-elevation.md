## Install System Elevation Plan

### Overview
Leverage strengths of the current GNU Stow-based, multi-distro installer while integrating insights from the Omarchy audit to deliver a richer, more automated experience.

### Objectives
- Retain modular architecture, idempotency, and multi-platform support.
- Provide optional rich UX with interactive feedback and error recovery.
- Expand hardware automation coverage via modular detection and scripts.
- Improve first-run/post-install experience and validation.
- Introduce tooling to reconcile curated package bundles.

### Enhancements

1. **Presentation Layer**
   - Optional Gum-powered front-end with live log tailing and interactive prompts.
   - Headless mode remains default (TUI enabled via flag/env).
   - Integration via wrapper `scripts/install/ui.sh`.

2. **Hardware Automation Library**
   - Introduce `scripts/hardware/modules/*.sh` with detection guards.
   - Each module uses `install-state` markers and safe `/etc` manipulation helpers.
   - Host or platform detection invokes modules automatically.

3. **Post-Install / First-Run Workflow**
   - Create `scripts/install/first-run` orchestrator, triggered optionally or for fresh installs.
   - Includes firewall, network, welcome, theme verification tasks.
   - Uses sudoers helper to add/remove temporary privileges.

4. **Package Bundle Curation**
   - Define bundle manifests in `packages/bundles/*.yaml`.
   - Add CLI (`scripts/tools/package-bundles.sh`) to diff Omarchy lists, enable/disable bundles, and feed `install-deps.sh`.
   - Provides onboarding presets without sacrificing per-host logic.

5. **System Integration Safety Helpers**
   - New `scripts/lib/system-mods.sh` wrapping sudoers changes, mkinitcpio hook toggling, Docker config updates.
   - Ensures backups, idempotent merges, and multi-distro awareness.

6. **Validation & Telemetry**
   - Expand `scripts/install/validate.sh` to emit summary tables, optional log bundle, and migration state review.
   - Hook into Gum UI when enabled to present results interactively.

### Architecture Notes
- Entry point (`install.sh`) gains flags to enable UI, hardware auto modules, first-run schedule.
- Harness existing `install-state` to gate new modules.
- Keep Stow package discovery unchanged; enhancements complement, not replace.

### Next Steps
1. Implement UI wrapper with feature flag and log tail integration.
2. Build hardware module framework; port high-priority scripts (Apple, Surface, NVIDIA, Bluetooth/regdom).
3. Develop first-run orchestrator with optional triggers.
4. Create package bundle manifests and supporting CLI.
5. Author system-mods helper and retrofit existing scripts.
6. Enhance validation script and integrate with UI option.

### Impact Assessment
- **Modularity Preserved:** Enhancements are layered atop existing Stow/package/host architecture with opt-in toggles.
- **Automation Compatibility:** Headless mode remains default; UI and first-run features activate only when requested.
- **Security Improvements:** Centralized helpers for sudoers, mkinitcpio, and Docker edits ensure backups and idempotent merges.
- **Maintainability:** Hardware modules encapsulate detection logic and state tracking, simplifying future vendor-specific work.
- **Portability:** Bundle manifests consumed by current package installer keep Arch/Debian parity manageable.

### Implementation Roadmap
1. **Foundation**
   - Add `system-mods.sh` helper and retrofit existing scripts touching `/etc`.
   - Introduce new CLI flags/env vars in `install.sh` to toggle UI, hardware modules, first-run workflow.
2. **Experience Layer**
   - Implement Gum-based UI wrapper with log tailing and error handling.
   - Upgrade `validate.sh` to produce summarized reports (text + TUI).
3. **Automation Modules**
   - Scaffold hardware module framework; port priority fixes (Apple T2, Surface, NVIDIA, regdom, printer, USB autosuspend).
   - Create package bundle manifests + CLI tooling; integrate with `install-deps.sh`.
4. **Post-Install Enhancements**
   - Build first-run orchestrator and tasks (firewall, Wi-Fi, welcome, theme checks).
   - Document user flows and configuration in `docs/`.
5. **Polish & QA**
   - Add lint/tests for bundle manifests and hardware module detection.
   - Run end-to-end validation across representative hosts/distros and adjust flags as needed.

