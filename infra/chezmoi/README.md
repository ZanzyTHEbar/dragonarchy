# chezmoi Source Root

This directory is the future user-state source root for the new architecture.

## Ownership

chezmoi owns:

- user dotfiles in `$HOME`
- host-aware rendered user configuration
- user secrets integration
- machine-specific user-level differences

chezmoi does not own:

- `/etc`
- system packages
- system services
- hardware state

## Foundation batch

This directory is intentionally minimal in the foundation phase.

The goal is to establish:

- the control-plane location
- ownership boundaries
- a clean source root for future user-state migration

The foundation phase does not yet migrate existing Stow packages into chezmoi.

## Planned invocation model

The future control path should treat this directory as the explicit chezmoi source:

```bash
chezmoi --source ~/dotfiles/infra/chezmoi diff
chezmoi --source ~/dotfiles/infra/chezmoi apply
```

Those commands are documented here as the intended model, not as an already-supported migration path.
