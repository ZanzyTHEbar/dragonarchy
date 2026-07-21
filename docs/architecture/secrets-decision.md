# Secrets Architecture Decision

## Status

**Approved** — 2026-05-11

## Context

The repository already uses sops + age for secrets management (`assets/secrets/secrets.yaml`). The migration to Ansible + chezmoi requires explicit ownership of secrets handling.

## Decision

| Secret Type | Owner | Tool | Location |
|-------------|-------|------|----------|
| System-level secrets (service credentials, SSH host keys) | Ansible | Ansible Vault | `infra/ansible/inventory/group_vars/` or `host_vars/` |
| User-level secrets (API keys, signing keys, personal tokens) | chezmoi | age (native chezmoi) | Encrypted files in chezmoi source tree |
| Shared secrets (common API keys, database passwords) | sops + age | sops | `assets/secrets/secrets.yaml` (canonical) |

## Rationale

1. **Ansible Vault** is the native Ansible secrets solution. It integrates cleanly with playbooks and requires no additional tooling beyond `ansible-vault`.
2. **chezmoi age** is the native chezmoi encryption solution. It handles per-file encryption in the chezmoi source tree and decrypts automatically on `chezmoi apply`.
3. **sops + age** remains the canonical source for shared secrets that both system and user state may need. It is kept as the single source of truth for cross-cutting secrets.

## Workflow

### Adding a system secret

```bash
# Create encrypted vault file
ansible-vault create infra/ansible/inventory/host_vars/dragon/vault.yml

# Reference in playbook
# {{ vault_my_secret }}
```

### Adding a user secret

```bash
# In the chezmoi generated source tree
chezmoi encrypt ~/.config/myapp/secret.conf
# Move the encrypted file into the manifest source path
```

### Updating shared secrets

```bash
# Edit with sops
sops assets/secrets/secrets.yaml

# Commit the encrypted file
```

## Migration Path

1. **Immediate**: Document this decision. No tooling changes required.
2. **Phase 2**: Migrate `assets/secrets/secrets.yaml` contents into Ansible Vault (system) and chezmoi age (user) as manifests expand.
3. **Phase 3**: Retire `assets/secrets/secrets.yaml` once all consumers have moved to their respective control planes.

## Exceptions

- The existing `assets/secrets/secrets.yaml` remains the canonical shared source until Phase 3.
- No secrets should be committed in plaintext to the repository.
- Secret templates (e.g., `.chezmoitemplates/secrets`) must be encrypted if they contain real values.

## References

- [Ansible Vault documentation](https://docs.ansible.com/ansible/latest/vault_guide/vault.html)
- [chezmoi Encryption](https://www.chezmoi.io/user-guide/encryption/)
- [sops documentation](https://github.com/getsops/sops)
