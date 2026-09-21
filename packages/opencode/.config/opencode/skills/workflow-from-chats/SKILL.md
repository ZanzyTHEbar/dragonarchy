---
name: workflow-from-chats
description: Extract durable working preferences from recent opencode sessions and convert them into skills, rules, or workflow docs. Use when asked to learn preferences, mine feedback, personalize workflows, or generate team/person-specific agent guidance.
---

# Workflow From Sessions

Infer durable working preferences from recent opencode sessions. Do not summarize sessions; extract reusable workflow guidance.

Source of truth is opencode session history:

```bash
opencode session list -n 20 --format json
opencode export <sessionID> --sanitize
```

Filter listed sessions to the current project directory first, then the last 7 days unless the user asks for a different window. Read the exported parent session and its subagent parts as evidence, but cite only parent sessions.

If session access is unavailable, use only the current conversation and explicit user-provided excerpts. Do not invent a broader evidence corpus.

## Scope

- Default to the last 7 days unless the user asks for a different window.
- Prefer sessions with the same project directory as the current task.
- Use subagent content as evidence, but cite only parent sessions.
- Do not expose local session paths, secrets, customer data, private session content, or credentials.

## Workflow

1. State the target workflow or preference surface in one paragraph.
2. Build an internal session inventory: title/topic, parent session ID if safe to disclose, approximate date, completion state, relevant subagents, and why it may contain preference evidence.
3. Scan for explicit preferences, corrections, and workflow markers such as "I prefer", "always", "never", "not what I asked", "stop", "review", "PR", "CI", "logs", and "skill".
4. Extract preference atoms: trigger, workflow step, decision rule, quality bar, stop condition, evidence, and confidence.
5. Rate confidence as strong, medium, weak, or contradicted.
6. Cluster by workflow shape rather than session: shipping, review, simplification, debugging, capture, communication, delegation, or validation.
7. Choose the artifact: new skill, skill edit, rule, workflow doc, Memory Bank update, or no artifact.
8. Draft only the reusable guidance. Filter anecdotes that will not help future tasks.

## Confidence

- Strong: explicit user preference, workflow-changing correction, repeated parent-session pattern, or direct request to encode behavior.
- Medium: accepted workflow, repeated tool/model/validation preference, or subagent consensus that the parent used successfully.
- Weak: agent-chosen behavior with no user feedback, one ambiguous session, or a likely task-specific correction.
- Contradicted: evidence points in incompatible directions; ask the user before writing files.

## Artifact Choice

- Skill: recurring multi-step workflow with clear triggers.
- Rule: general behavior that should apply broadly.
- Workflow doc or Memory Bank: useful context that is not reliably triggerable but should persist.
- No artifact: situational, stale, or low-confidence observation.

## Output

Return a concise synthesis first:

- Target workflow.
- Evidence corpus with safe parent session citations only.
- Preference profile.
- Adopt, consider, dismissed.
- Proposed artifacts.
- Open questions only if they block writing.
