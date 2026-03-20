# Agentic Systems

TLA+ is unusually well-suited to agentic systems because most agent frameworks are already informal state machines:

- agents have internal state
- tools produce partial and fallible observations
- humans may approve or deny
- messages arrive late, duplicate, or never arrive
- retries and handoffs create interleavings

The mistake is to model the prompt text.
The right move is to model the decision structure and failure envelope.

## 1. What to Model

For an LLM-driven or multi-agent workflow, the useful variables are usually:

- control state: `pc`, `phase`, `status`
- task state: pending, active, done, failed
- communication state: `inbox`, `outbox`, `pendingCalls`
- tool state: queued, running, success, failure, timed out
- approval state: requested, granted, denied
- artifact state: draft, validated, committed
- resource state: locks, quotas, write permissions

Ignore:

- token-by-token generation
- raw model logits
- full prompt bodies unless a property depends on prompt class
- real-time latency distributions unless the property depends on time

## 2. Treat the LLM as Bounded Nondeterminism

Do not model "the model can generate any string."
Model a finite set of allowed choices.

Example:

```tla
AllowedDecisions == {"Plan", "CallTool", "AskUser", "Abort"}

AgentStep(a) ==
    \E d \in AllowedDecisions :
        CASE d = "Plan"     -> Plan(a)
          [] d = "CallTool" -> CallTool(a)
          [] d = "AskUser"  -> AskUser(a)
          [] d = "Abort"    -> Abort(a)
```

This captures nondeterminism without creating an uncheckable text universe.

## 3. Model the Environment Adversarially

If the system touches tools, APIs, humans, or storage, the environment deserves explicit actions.

Typical environment actions:

- `ToolFails`
- `ToolReturnsStaleData`
- `ResponseDelayed`
- `UserRejects`
- `UserNeverReplies`
- `WriteLost`
- `DuplicateMessage`

If the real system can experience it and the property depends on it, model it.

## 4. High-Value Safety Invariants

These are common, useful invariants for agentic coding systems:

- At most one mutation is in flight for a protected target
- No external write occurs without the required approval state
- A completed task has exactly one terminal status
- A tool result is not consumed before the tool reports success
- A message is not both pending and delivered
- Ownership or lock invariants are never violated
- An artifact cannot be marked verified unless its checks passed

Example:

```tla
NoUnapprovedWrite ==
    \A a \in Agents :
        status[a] = "Writing" => approval[a] = "Granted"
```

## 5. High-Value Liveness Properties

Only add these once the safety model is stable.

Useful examples:

- every approved task is eventually completed or failed explicitly
- every tool call eventually resolves under fairness assumptions
- every queued message is eventually consumed
- every blocked agent is eventually unblocked if the dependency is cleared

Be explicit about assumptions.
If a human may ignore the system forever, "eventually approved" is not a valid property.

## 6. Human-in-the-Loop Modeling

Human approval is not magic.
Model it as a separate actor or environment action:

- request approval
- grant approval
- deny approval
- do nothing

That usually exposes the real design question:
what must happen if the human never answers?

## 7. Tool-Call Pattern

The minimal useful abstraction often looks like:

```tla
VARIABLES toolState, pendingCalls, results

TypeOK ==
    /\ toolState \in [Tools -> {"Idle", "Running", "Succeeded", "Failed"}]
    /\ pendingCalls \subseteq Calls
    /\ results \subseteq Results
```

Then define:

- issue call
- tool succeeds
- tool fails
- retry
- cancel

This is usually enough to prove "no result is consumed before success" or "retries never exceed budget."

## 8. Multi-Agent Coordination Pattern

For cooperating agents, separate:

- local agent state
- shared coordination state
- communication medium
- arbiter or scheduler behavior

Do not let every agent mutate every variable unless the real design allows it.
Restrict write authority in the model just as you would in production.

## 9. Verified-to-Code Translation

After the spec is stable, map it into code intentionally.

### Preserve directly

- state-machine phases
- guards and preconditions
- invariants as assertions or validation rules
- retry limits
- approval gates

### Do not over-translate

- fairness assumptions are not code
- symmetry is not code
- tiny model bounds are not production limits unless intentionally chosen

The code should preserve the behavioral contract, not the checker setup.

## 10. Recommended Workflow for Agentic Coding

1. Write the user-visible contract in plain English
2. Extract state variables and actors
3. Model one happy-path cycle
4. Add one failure mode at a time
5. Check safety invariants
6. Add progress assumptions only when justified
7. Translate the stable spec into implementation states, guards, and tests

## 11. Example Prompt Shapes

These prompt shapes are good inputs for this skill:

```text
Model this coding agent workflow in TLA+:
- one planner agent
- one executor agent
- a human approval gate before writes
- tool calls may fail or time out
- no file may be committed without validation
```

```text
Turn this multi-agent design into a small PlusCal spec with N = 2 workers and an explicit environment action for dropped messages.
```

```text
TLC is exploding on this agent workflow. Reduce the model while preserving the invariant that at most one deployment runs at a time.
```

## 12. Anti-Patterns in Agentic Specs

### Modeling prompt text directly

Use symbolic classes of decisions instead.

### Assuming reliable tools by default

Most real bugs live in partial failure and stale observations.

### Skipping human non-response

If a human gate exists, inactivity is part of the system.

### Translating the spec into code too early

Get the behavioral contract right first.

### Using fairness to fake product guarantees

If production cannot guarantee it, do not assume it in the spec.

## 13. Why This Matters

Agentic systems fail in the cracks:

- between planner and executor
- between tool call and tool result
- between approval request and approval receipt
- between "validated" and "committed"

Those cracks are exactly what TLA+ is good at modeling.
If the system is concurrent, asynchronous, retried, distributed, or human-gated, formal state-machine thinking pays off fast.
