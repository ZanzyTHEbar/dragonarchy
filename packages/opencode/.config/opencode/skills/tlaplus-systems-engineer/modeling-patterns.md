# Modeling Patterns

Use these patterns to keep specs readable, scalable, and falsifiable.
The common theme is to model behavior directly and keep every state variable justified by a property you care about.

## 1. Mandatory Skeleton

Most useful specs benefit from this structure:

```tla
VARIABLES ...
vars == <<...>>

TypeOK == ...
Init == ...

ActionA == ...
ActionB == ...
EnvStep == ...

Next == ActionA \/ ActionB \/ EnvStep
Spec == Init /\ [][Next]_vars
```

Name sub-actions. Avoid one giant `Next` body.

## 2. `TypeOK` Pattern

Treat `TypeOK` as the shape contract of the state.

```tla
TypeOK ==
    /\ owner \in Agents \cup {"none"}
    /\ queue \in Seq(Messages)
    /\ pc \in [Agents -> {"Idle", "Waiting", "Critical"}]
```

If `TypeOK` is weak, debugging gets harder and state space gets wider.

## 3. Environment as an Explicit Actor

Do not hide failures or scheduling inside informal text.
Model them as actions.

Examples:

- `EnvDropMessage`
- `EnvDelay`
- `EnvCorruptCache`
- `HumanApproves`
- `HumanRejects`

This keeps the proof honest.

## 4. Named Sub-Actions by Intent

Prefer:

```tla
Send(a, m) == ...
Receive(a) == ...
Timeout(a) == ...
Retry(a) == ...
```

Instead of:

```tla
Next == \E a, m : ...
```

The explicit form makes traces and fairness much easier to interpret.

## 5. Queue vs Set vs Bag

Choose the cheapest structure that preserves the property.

### Use a sequence when order matters

- FIFO delivery
- replay logs
- ordered retries

### Use a set when order does not matter

- outstanding requests
- granted capabilities
- ready workers

### Use a bag or count abstraction when multiplicity matters but order does not

- duplicate messages
- retry budgets
- resource inventory

If you do not need ordering, do not pay for ordering.

## 6. Ownership and Resource Patterns

### Single-owner lock

```tla
LockFree == owner = "none"
Owns(a) == owner = a
```

### Limited-capacity resource

```tla
TypeOK == permits \in 0..MaxPermits
Acquire == /\ permits > 0 /\ permits' = permits - 1
Release == /\ permits < MaxPermits /\ permits' = permits + 1
```

This is usually better than tracking individual identical permits.

## 7. Message-Passing Pattern

For distributed systems, start with:

```tla
VARIABLES inbox, sent, delivered

TypeOK ==
    /\ inbox \in [Agents -> SUBSET Messages]
    /\ sent \subseteq Messages
    /\ delivered \subseteq Messages
```

Then decide what failure model you need:

- perfect delivery
- loss
- duplication
- reordering
- delay

Model only the failures relevant to the property.

## 8. Program Counter Pattern

When one action does too much, add `pc`.

```tla
TypeOK == pc \in [Agents -> {"Idle", "Prepare", "Commit"}]

Prepare(a) ==
    /\ pc[a] = "Idle"
    /\ pc' = [pc EXCEPT ![a] = "Prepare"]
    /\ UNCHANGED <<queue, owner>>

Commit(a) ==
    /\ pc[a] = "Prepare"
    /\ ...
```

Benefits:

- clearer interleavings
- smaller action bodies
- easier fairness on specific phases
- easier counterexample reading

This is often the cleanest fix for state-space explosion caused by oversized atomic steps.

## 9. Symmetry Pattern

If agents are interchangeable, exploit that.

Typical signs symmetry is valid:

- all workers follow the same rules
- identities are irrelevant to the property
- you only care that "some agent" acts

Then keep the model symmetric and use symmetry reduction in the checker config.

Break symmetry only when identity matters, for example:

- one leader and many followers
- one privileged actor
- per-agent quotas or capabilities

## 10. Bounded Nondeterminism

Nondeterminism is good. Unbounded nondeterminism is usually a TLC killer.

Prefer:

```tla
\E a \in Agents : Step(a)
```

Over anything that effectively creates unbounded data or time.

For agentic systems, model "the LLM may choose one of these actions" as a finite set of legal decisions, not arbitrary text generation.

## 11. Time, Retries, and Backoff

Avoid wall-clock modeling until absolutely necessary.

Use:

- retry counters
- logical timeout flags
- bounded delay slots
- scheduler actions

Instead of:

- real timestamps
- full timer heaps
- unbounded elapsed-time arithmetic

Logical time is cheaper and usually sufficient for safety reasoning.

## 12. Histories and Debug Variables

History variables are useful when:

- the property talks about "already seen" behavior
- you want easier traces
- refinement mapping needs past context

But histories are expensive.
If a boolean, counter, or derived set can replace a full history, do that instead.

## 13. Refinement-Friendly Structure

If the spec will later drive code generation or implementation review:

- keep abstract state separate from helper state
- isolate environment assumptions
- document what each variable corresponds to in code
- prefer stable, named invariants over one-off assertions

That makes the spec easier to translate into tests, runtime guards, and design docs.

## 14. Common Anti-Patterns

### Modeling payload details that do not affect the property

Bad for state count and usually irrelevant.

### One giant omnipotent action

Hard to debug, hard to constrain, hard to assign fairness to.

### Mixing system and environment updates in one action

This hides responsibility and makes traces confusing.

### Using sequences everywhere

Order is expensive. Use it only when the property needs it.

### Encoding human prose directly in the model

Represent a decision as a small symbolic domain, not the raw prompt or response text.

## 15. A Good Default Workflow

For a new design:

1. Start with the minimal state that can express the safety property
2. Add one environment failure mode at a time
3. Split actions when traces become hard to read
4. Add liveness only after the model is easy to search
5. Increase parameter sizes only after the small model is clean

That workflow catches more real bugs than jumping straight to a realistic, huge model.
