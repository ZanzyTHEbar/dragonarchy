# Authentik ORM Patterns

Proven recipes for common Authentik operations via Django ORM.

## User Operations

### Query all users

```python
for u in User.objects.exclude(username__startswith='ak-').exclude(username='AnonymousUser'):
    groups = list(u.ak_groups.values_list('name', flat=True))
    print(f"{u.username}: type={u.type}, email={u.email}, groups={groups}")
    print(f"  has_usable_password={u.has_usable_password()}")
```

### Fix unusable password

```python
user = User.objects.get(username='target')
user.set_password('new_password')
user.save(update_fields=['password'])
user.refresh_from_db()
assert user.check_password('new_password')
```

### Clear reputation penalties

```python
from authentik.policies.reputation.models import Reputation
Reputation.objects.filter(identifier='username').delete()
Reputation.objects.filter(ip='172.22.0.1').delete()
```

## Group Operations

### List groups with members

```python
for g in Group.objects.all().order_by('name'):
    users = list(g.users.values_list('username', flat=True))
    print(f"{g.name}: parent={g.parent}, users={users}, attrs={g.attributes}")
```

### Create a group

```python
group, created = Group.objects.get_or_create(
    name='my-group',
    defaults={'attributes': {}}
)
group.users.add(User.objects.get(username='someone'))
```

## Flow Operations

### Inspect a flow's stage bindings

```python
flow = Flow.objects.get(slug='flow-slug')
for fsb in FlowStageBinding.objects.filter(target=flow).order_by('order'):
    policies = PolicyBinding.objects.filter(target=fsb)
    pnames = [pb.policy.name for pb in policies]
    stage = fsb.stage
    print(f"order={fsb.order}: {stage.name} ({stage.__class__.__name__})")
    print(f"  eval_on_plan={fsb.evaluate_on_plan} re_eval={fsb.re_evaluate_policies}")
    print(f"  policies={pnames}")
```

### Create a flow stage binding with policy

```python
fsb = FlowStageBinding.objects.create(
    target=flow,
    stage=some_stage,
    order=10,
    evaluate_on_plan=False,
    re_evaluate_policies=True,
)
PolicyBinding.objects.create(
    target=fsb,
    policy=some_policy,
    order=0,
    enabled=True,
)
```

### Clear and rebuild a flow

```python
FlowStageBinding.objects.filter(target=flow).delete()
# Then recreate bindings in order
```

## Stage Operations

### UserWriteStage (critical fields)

```python
from authentik.core.models import UserTypes

stage, created = UserWriteStage.objects.get_or_create(
    name='my-write-stage',
    defaults={
        'user_creation_mode': 'always_create',  # or 'never_create' for linking
        'create_users_as_inactive': False,
        'create_users_group': Group.objects.get(name='bundle-standard'),
        'user_type': UserTypes.INTERNAL,  # ALWAYS set this, default is external
    }
)
```

### IdentificationStage with sources

```python
ident_stage, _ = IdentificationStage.objects.get_or_create(
    name='my-identification',
    defaults={'user_fields': []},  # empty = source buttons only
)
ident_stage.sources.set([OAuthSource.objects.get(slug='google')])
```

### PasswordStage backends

```python
pwd_stage = PasswordStage.objects.get(name='default-authentication-password')
print(pwd_stage.backends)
# Typical: ['authentik.core.auth.InbuiltBackend', 'authentik.sources.ldap.auth.LDAPBackend']
```

## Policy Operations

### Expression policy (side-effect pattern)

Used to write to the session from within a flow without blocking it:

```python
policy, _ = ExpressionPolicy.objects.get_or_create(
    name='my-side-effect-policy',
    defaults={'expression': """
request.http_request.session['my_flag'] = True
request.http_request.session.save()
return False  # Skip the stage this is bound to
"""}
)
```

Bind to a DenyStage with `evaluate_on_plan=False, re_evaluate_policies=True`.
The policy writes to the session, returns False (skipping the DenyStage), and the flow continues.

### Expression policy (gate pattern)

```python
policy, _ = ExpressionPolicy.objects.get_or_create(
    name='my-gate-policy',
    defaults={'expression': """
return request.http_request.session.get('my_flag', False)
"""}
)
```

Returns True → stage executes. Returns False → stage skipped.

## OAuth Source Operations

### Inspect Google source

```python
src = OAuthSource.objects.get(slug='google')
print(f"enrollment_flow: {src.enrollment_flow}")
print(f"authentication_flow: {src.authentication_flow}")
print(f"user_matching_mode: {src.user_matching_mode}")
print(f"consumer_key: {src.consumer_key[:20]}...")
```

## Invitation Operations

### Create an invitation

```python
from authentik.stages.invitation.models import Invitation
inv = Invitation.objects.create(
    name='descriptive-name',
    created_by=User.objects.get(username='akadmin'),
    single_use=True,
)
print(f"Link: https://auth.zacariahheim.com/if/flow/enrollment-invitation/?itoken={inv.pk}")
```

### List active invitations

```python
for inv in Invitation.objects.filter(expiring=True):
    print(f"{inv.name}: pk={inv.pk}, single_use={inv.single_use}, expires={inv.expires}")
```

## SMTP / Email Testing

```python
from django.core.mail import send_mail
from django.conf import settings

result = send_mail(
    subject="Authentik Test",
    message="SMTP test from Authentik.",
    from_email=settings.DEFAULT_FROM_EMAIL,
    recipient_list=["target@example.com"],
    fail_silently=False,
)
print(f"Sent: {result}")
```
