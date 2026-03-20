---
name: authentik-admin
description: Manage Authentik identity provider via Django ORM over SSH. Covers user management, group/bundle administration, flow and stage configuration, OAuth source setup, invitation workflows, and expression policies. Use when the user mentions authentik, identity provider, SSO, OAuth source, enrollment, invitation, password reset, user groups, bundles, flows, stages, or policies on DragonServer.
---

# Authentik Administration

Use this skill for programmatic Authentik configuration and management.
Authentik runs as a Docker container on `cool-res` and is managed entirely through its Django ORM via `docker exec`.

## Quick Start

1. Identify the operation type (read-only query vs mutation).
2. Use the ORM exec pattern to run Python against the Authentik container.
3. Always import Django setup boilerplate before model access.
4. Validate results after every mutation.

## Access Pattern

All Authentik operations run through a single channel:

```bash
ssh -o BatchMode=yes cool-res "docker exec -i authentik-server-i4oogsg08sgok8scc440ogog python -"
```

Pipe a Python script via stdin. Always begin scripts with:

```python
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
import django
django.setup()
```

For multi-command orchestration from the local workstation, wrap in a subprocess call:

```python
import subprocess, textwrap

CONTAINER = 'authentik-server-i4oogsg08sgok8scc440ogog'

script = textwrap.dedent('''
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'authentik.root.settings')
import django
django.setup()

# ORM operations here
''')

subprocess.run(
    ['ssh', '-o', 'BatchMode=yes', 'cool-res',
     f'docker exec -i {CONTAINER} python -'],
    input=script, text=True, check=True
)
```

## Core Model Imports

```python
from authentik.core.models import User, Group, Application, UserTypes
from authentik.flows.models import Flow, FlowStageBinding, FlowDesignation
from authentik.stages.identification.models import IdentificationStage
from authentik.stages.password.models import PasswordStage
from authentik.stages.user_write.models import UserWriteStage
from authentik.stages.user_login.models import UserLoginStage
from authentik.stages.invitation.models import InvitationStage, Invitation
from authentik.stages.email.models import EmailStage
from authentik.stages.deny.models import DenyStage
from authentik.policies.expression.models import ExpressionPolicy
from authentik.policies.models import PolicyBinding
from authentik.sources.oauth.models import OAuthSource
```

## Operating Rules

1. **ORM over API.** Prefer Django ORM for all configuration. The REST API is useful for reads but ORM is more reliable for mutations.
2. **Always verify.** Query back the object after creation or update.
3. **UserWriteStage quirks.** `create_users_group` is a ForeignKey (single group), not ManyToMany. `user_type` defaults to `external` — always set to `internal` for regular users.
4. **FlowStageBinding policies.** Set `evaluate_on_plan=False` and `re_evaluate_policies=True` when policies must run at stage execution time, not at flow plan build time.
5. **Expression policies** have access to `request.user`, `request.http_request`, `request.context`, and can import any Django model. They are the primary extensibility mechanism.
6. **Password hashes.** A password starting with `!` means unusable. Use `user.set_password()` to fix, never raw assignment.
7. **Reputation system.** Failed logins accumulate penalties. Clear with `Reputation.objects.filter(identifier='username').delete()` after fixing auth issues.

## Workflow: User Management

```python
user = User.objects.get(username='someone')
user.set_password('new_password')
user.type = UserTypes.INTERNAL
user.save(update_fields=['password', 'type'])
user.refresh_from_db()
assert user.check_password('new_password')
```

## Workflow: Invitation + Google Enrollment

New users are enrolled through invitation links with Google OAuth:

1. Admin creates an `Invitation` in the Authentik admin UI or via ORM.
2. User opens `https://auth.zacariahheim.com/if/flow/enrollment-invitation/?itoken=<uuid>`.
3. `InvitationStage` validates the token.
4. Session is marked with `_invitation_validated=True` (via expression policy side-effect on a skipped DenyStage).
5. `IdentificationStage` shows only the Google button.
6. User authenticates with Google → callback → source enrollment flow.
7. Source enrollment flow checks session flag → auto-creates user as `internal` in `bundle-standard` group.
8. Bundle sync policy on login stage propagates child group memberships.

Without a valid invitation token, step 3 fails and enrollment is denied.

## Workflow: Bundle Group Sync

Groups are managed through a bundle system. Bundle groups have `attributes.is_bundle=True` and `attributes.child_groups=[...]`.

- Adding a user to a bundle auto-populates child groups on next login.
- Removing from a bundle removes inherited (not direct) child groups on next login.
- The `bundle-group-sync` expression policy runs on every login stage.
- User attributes track `_inherited_groups` and `_direct_groups` for clean separation.

See [group-system.md](group-system.md) for current bundles, group hierarchy, and management recipes.

## Key Identifiers

| Resource | Identifier |
|---|---|
| Authentik service UUID | `i4oogsg08sgok8scc440ogog` |
| Server container | `authentik-server-i4oogsg08sgok8scc440ogog` |
| Worker container | `authentik-worker-i4oogsg08sgok8scc440ogog` |
| Service directory | `/data/coolify/services/i4oogsg08sgok8scc440ogog/` |
| Auth URL | `https://auth.zacariahheim.com` |
| SMTP | Gmail via `zacariahheim@gmail.com` (app password) |

## Known Limitations

- **Coolify env API unreliable.** For env var changes, edit `/data/coolify/services/<uuid>/.env` directly via SSH, then `docker compose up -d --force-recreate`.
- **Gmail SMTP deduplication.** Emails sent FROM `zacariahheim@gmail.com` TO `*@zacariahheim.com` addresses that Cloudflare routes back to the same Gmail will be silently dropped. Only affects admin/internal accounts, not Google-enrolled users.
- **Expression policy context.** When a new flow starts (e.g., OAuth callback), the old flow's plan is deleted. Use `request.http_request.session` to persist data across flow boundaries.

## Progressive Disclosure References

- [orm-patterns.md](orm-patterns.md): Proven ORM recipes for common operations.
- [flow-architecture.md](flow-architecture.md): Complete flow/stage/policy structure.
- [group-system.md](group-system.md): Bundle groups, hierarchy, and sync mechanism.
