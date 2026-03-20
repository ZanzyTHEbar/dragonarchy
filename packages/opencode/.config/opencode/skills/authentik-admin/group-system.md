# Authentik Group System

## Bundle Architecture

Bundle groups are meta-groups that auto-propagate membership to child groups.
They are identified by `attributes.is_bundle=True` and define children in `attributes.child_groups`.

### Current Bundles

| Bundle | Children | Purpose |
|---|---|---|
| `bundle-standard` | `authentik-users`, `mealie-users`, `opencloud-users`, `openwebui-users`, `budget-viewers` | Standard user access to all apps |
| `bundle-admin` | `authentik-users`, `mealie-admins`, `mealie-users`, `opencloud-admins`, `opencloud-spaceadmins`, `opencloud-users`, `openwebui-users` | Full admin access |

### Group Hierarchy

```
bundle-standard [BUNDLE]
├── mealie-users
├── opencloud-users
├── openwebui-users
└── budget-viewers

bundle-admin [BUNDLE]
├── mealie-admins
├── opencloud-admins
└── opencloud-spaceadmins

authentik-users (standalone)
opencloud-guests (standalone, unused)
authentik Admins (standalone, Authentik admin access)
budget-admins (standalone, ntfy admin role)
budget-services (standalone, service accounts for budget guard)
budget-viewers (in bundle-standard, ntfy per-user topic access)
```

## Sync Mechanism

The `bundle-group-sync` expression policy runs on every login stage.

**Sync logic:**
1. Find all bundle groups the user belongs to.
2. Compute the union of all `child_groups` from those bundles → `desired_inherited`.
3. Compare with previously stored `_inherited_groups` in user attributes.
4. ADD groups in `desired_inherited` that the user doesn't have.
5. REMOVE groups from `_inherited_groups` that are no longer desired AND not in `_direct_groups`.
6. Update `user.attributes._inherited_groups` with the new set.

**Key attributes on user objects:**
- `_inherited_groups`: Groups added via bundle sync (managed by the system).
- `_direct_groups`: Groups that were assigned manually (never removed by sync).

## Management Recipes

### Add a user to a bundle

```python
bundle = Group.objects.get(name='bundle-standard')
user = User.objects.get(username='someone')
bundle.users.add(user)
# Child groups propagate on next login via bundle-group-sync policy
```

### Immediate sync (without waiting for login)

```python
user = User.objects.get(username='someone')
bundles = Group.objects.filter(users=user, attributes__is_bundle=True)
desired = set()
for b in bundles:
    desired.update(b.attributes.get('child_groups', []))

for gname in desired:
    try:
        g = Group.objects.get(name=gname)
        g.users.add(user)
    except Group.DoesNotExist:
        pass

attrs = user.attributes or {}
attrs['_inherited_groups'] = sorted(desired)
user.attributes = attrs
user.save(update_fields=['attributes'])
```

### Create a new bundle

```python
bundle, _ = Group.objects.get_or_create(
    name='bundle-my-bundle',
    defaults={
        'attributes': {
            'is_bundle': True,
            'description': 'What this bundle provides',
            'child_groups': ['group-a', 'group-b', 'group-c'],
        },
    }
)
```

### Modify a bundle's children

```python
bundle = Group.objects.get(name='bundle-standard')
attrs = bundle.attributes
attrs['child_groups'].append('new-app-users')
bundle.attributes = attrs
bundle.save()
```

### Assign a user directly to a group (bypass bundle)

```python
user = User.objects.get(username='someone')
group = Group.objects.get(name='mealie-admins')
group.users.add(user)

attrs = user.attributes or {}
direct = set(attrs.get('_direct_groups', []))
direct.add('mealie-admins')
attrs['_direct_groups'] = sorted(direct)
user.attributes = attrs
user.save(update_fields=['attributes'])
```

## Current User Assignments

| User | Bundles | Direct Extras |
|---|---|---|
| `akadmin` | `bundle-admin` | `authentik Admins`, `budget-admins` |
| `personal` | `bundle-standard` | `mealie-admins`, `opencloud-spaceadmins`, `budget-viewers` |
| `marildafamorosapaulo` | `bundle-standard` | `opencloud-spaceadmins` |
| `pyr0ndet0s97` | `bundle-standard` | — |
| `janemccarthystudio` | `bundle-standard` | — |
| `guard-service` | — | `budget-services` |
| `ntfy-sync-bridge-sa` | — | `authentik Admins` (service account for API access) |

## New User Enrollment Default

Users enrolled via invitation + Google are auto-assigned to `bundle-standard` via the `google-invited-create` UserWriteStage (`create_users_group=bundle-standard`). The sync policy then adds all standard child groups on login.
