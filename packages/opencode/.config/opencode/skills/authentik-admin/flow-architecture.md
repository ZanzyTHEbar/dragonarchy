# Authentik Flow Architecture

Current flow, stage, and policy structure for this Authentik instance.

## Flow Inventory

| Flow Slug | Designation | Purpose |
|---|---|---|
| `default-authentication-flow` | authentication | Main login page |
| `default-source-authentication` | authentication | OAuth source callback (existing users) |
| `enrollment-invitation` | enrollment | Invitation-gated Google enrollment |
| `google-account-link` | enrollment | Google source enrollment (dual-path) |
| `default-recovery-flow` | recovery | Password reset via email |

## Default Authentication Flow

```
default-authentication-flow
├─ order=10: default-authentication-identification (IdentificationStage)
│    sources: [google]
│    user_fields: [email, username]
├─ order=20: default-authentication-password (PasswordStage)
│    backends: [InbuiltBackend, LDAPBackend]
│    policy: default-authentication-flow-password-stage
├─ order=30: default-authentication-mfa-validation (AuthenticatorValidateStage)
└─ order=100: default-authentication-login (UserLoginStage)
     policy: bundle-group-sync (syncs bundle memberships on login)
```

## Enrollment-Invitation Flow

Invitation-gated enrollment with Google OAuth only.

```
enrollment-invitation
├─ order=0: enrollment-invitation (InvitationStage)
│    Validates itoken URL parameter. Denies if missing/invalid.
├─ order=5: invitation-session-marker (DenyStage) [SKIPPED]
│    policy: invitation-mark-session
│    Side-effect: sets session['_invitation_validated'] = True
│    Always returns False → DenyStage skipped, flow continues.
│    evaluate_on_plan=False, re_evaluate_policies=True
└─ order=10: enrollment-google-identification (IdentificationStage)
     sources: [google]
     user_fields: [] (Google button only, no form)
```

User clicks Google → redirected to Google OAuth → callback triggers google-account-link flow.

## Google Account Link Flow (Dual-Path)

Handles both new enrollment (with invitation) and existing user linking.

```
google-account-link
│
├─ [PATH A: Invited users — session has _invitation_validated=True]
│  order=0: google-invited-create (UserWriteStage)
│    policy: set-username-from-google-email
│    user_creation_mode: always_create
│    user_type: internal
│    create_users_group: bundle-standard
│    evaluate_on_plan=False, re_evaluate_policies=True
│
├─ [PATH B: Existing user linking — no invitation flag]
│  order=10: google-link-identification (IdentificationStage)
│    policy: invitation-gate-pass-if-NOT-validated
│  order=20: google-link-password (PasswordStage)
│    policy: invitation-gate-pass-if-NOT-validated
│  order=30: google-link-write (UserWriteStage)
│    policy: invitation-gate-pass-if-NOT-validated
│    user_creation_mode: never_create
│
└─ [SHARED]
   order=40: default-source-authentication-login (UserLoginStage)
     policy: invitation-clear-session + bundle-group-sync
```

## Expression Policy Inventory

| Policy Name | Purpose | Returns |
|---|---|---|
| `invitation-mark-session` | Writes `_invitation_validated=True` to session | `False` (skip DenyStage) |
| `invitation-gate-pass-if-validated` | Allows stage only when invitation flag is set | `True` if validated |
| `invitation-gate-pass-if-NOT-validated` | Allows stage only when NO invitation flag | `True` if not validated |
| `invitation-clear-session` | Cleans up `_invitation_validated` from session | `True` always |
| `set-username-from-google-email` | Derives username from Google email prefix, gates on invitation | `True` if validated |
| `bundle-group-sync` | Syncs bundle group memberships on every login | `True` always |
| `google-update-email-from-source` | Updates user email to Google email during linking | `True` always |

## Flow Execution Mechanics

**evaluate_on_plan vs re_evaluate_policies:**
- `evaluate_on_plan=True` (default): Policy runs when flow plan is built (before any stages execute). Use for static checks.
- `evaluate_on_plan=False` + `re_evaluate_policies=True`: Policy runs when the stage is about to execute. Use when the policy depends on state set by earlier stages.

**Session persistence across flows:**
When an OAuth callback starts a new flow, the old flow's plan is deleted. Data in `request.http_request.session` persists. This is how the invitation flag survives the Google redirect.

**Stage skipping:**
When a policy on a FlowStageBinding returns False, that stage is skipped and the next stage in the flow is tried. The flow does NOT terminate.

## Google OAuth Source Config

```
slug: google
provider_type: google
user_matching_mode: identifier
authentication_flow: default-source-authentication
enrollment_flow: google-account-link
```

The Google source appears on:
- Main login page (via `default-authentication-identification` sources)
- Enrollment-invitation flow (via `enrollment-google-identification` sources)
