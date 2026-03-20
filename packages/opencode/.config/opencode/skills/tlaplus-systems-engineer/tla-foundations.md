# TLA+ Foundations

`TLA` is the logic. `TLA+` is the specification language built on top of it.
The core engineering move is simple: model the system as a state machine, reason about all allowed behaviors, and ask whether desired properties hold for every behavior.

## 1. The Semantic Objects

### State

A state assigns a value to every variable in the model.
If your variables are `pc`, `queue`, and `owner`, then one state might mean:

- `pc = [a1 |-> "Idle", a2 |-> "Running"]`
- `queue = <<msg1>>`
- `owner = "none"`

### Action

An action is a relation between the current state and the next state.
Unprimed names refer to the current state. Primed names refer to the next state.

```tla
Acquire(a) ==
    /\ owner = "none"
    /\ owner' = a
    /\ UNCHANGED queue
```

This does not "run code". It declares which next states are allowed.

### Behavior

A behavior is an infinite sequence of states:

```text
s0, s1, s2, ...
```

TLA formulas describe sets of allowed behaviors, not single executions.

## 2. The Four Modeling Layers

TLA+ has a strict conceptual ladder:

1. Constants and ordinary math
2. State predicates
3. Actions
4. Temporal formulas

Most of a good spec is ordinary math over sets, functions, records, and sequences.
Temporal operators usually appear near the top of the spec, not everywhere.

## 3. Canonical Specification Shape

Most engineering specs reduce to:

```tla
Spec == Init /\ [][Next]_vars /\ Fairness
```

Where:

- `Init` is the set of legal initial states
- `Next` is the disjunction of all legal state transitions
- `vars` is the tuple of all variables, for example `<<pc, queue, owner>>`
- `Fairness` is optional and added only when you need liveness

A more explicit version usually looks like:

```tla
vars == <<pc, queue, owner>>

Init ==
    /\ pc = [a \in Agents |-> "Idle"]
    /\ queue = <<>>
    /\ owner = "none"

Next ==
    \/ \E a \in Agents : Acquire(a)
    \/ \E a \in Agents : Release(a)
    \/ EnvDropMessage

Spec == Init /\ [][Next]_vars
```

## 4. The Crucial Operators

### `UNCHANGED`

If an action does not modify a variable, say so explicitly:

```tla
UNCHANGED <<queue, owner>>
```

This avoids accidental under-specification.

### `[A]_vars`

The operator:

```tla
[A]_vars == A \/ UNCHANGED vars
```

means the next step either satisfies `A` or leaves all variables unchanged.
This is how TLA+ allows stuttering.

### `<<A>>_vars`

The non-stuttering form:

```tla
<<A>>_vars == A /\ ~UNCHANGED vars
```

Use this when you care that a real step occurred, not just an allowed stutter.

### `[]` and `<>`

- `[]P` means "always `P`"
- `<>P` means "eventually `P`"

Safety properties usually read as invariants.
Liveness properties usually say that something good eventually happens.

## 5. Stuttering Invariance

Stuttering is one of the most important ideas in TLA+.
The spec should not care whether an implementation takes one concrete step or five micro-steps, as long as the externally visible behavior is preserved.

Why this matters:

- Composition: one component can move while another stutters
- Refinement: low-level implementations can have more steps than high-level specs
- Asynchrony: delays, retries, and idle time become ordinary behaviors

If you do not understand stuttering, you will write fragile specs and incorrect liveness claims.

## 6. Safety vs Liveness

### Safety

Safety says "nothing bad ever happens."
Typical examples:

- a lock has at most one owner
- balance never goes negative
- a message is not delivered twice
- a write is never committed without approval

These are usually checked as invariants:

```tla
MutualExclusion == \A a, b \in Agents : (a /= b) => ~(pc[a] = "Critical" /\ pc[b] = "Critical")
```

### Liveness

Liveness says "something good eventually happens."
Typical examples:

- every enqueued message is eventually delivered
- every request is eventually resolved
- a waiting process eventually enters the critical section

Liveness requires assumptions about scheduling or fairness.
Without those assumptions, infinite stuttering is often allowed.

## 7. Fairness

Use fairness carefully.
It is easy to write a spec that "proves" progress only because the fairness assumptions are stronger than the real system.

### Weak Fairness

`WF_vars(A)` means: if `A` becomes continuously enabled from some point onward, then `A` must eventually occur.

This rules out behaviors where an action is forever enabled but forever ignored.

### Strong Fairness

`SF_vars(A)` means: if `A` is enabled infinitely often, then `A` must occur infinitely often.

This is stronger than weak fairness and should be used only when the real system justifies it.

### Engineering Rule

Fairness is usually better on sub-actions than on the entire `Next`.
Compare:

- too coarse: `WF_vars(Next)`
- better: `WF_vars(Send) /\ WF_vars(Receive)`

The second form explains exactly what kind of progress is assumed.

## 8. TLA+ vs PlusCal

`PlusCal` is an algorithm language that translates into TLA+.
It is excellent for:

- process-local control flow
- loops and retries
- step-by-step concurrent algorithms
- introducing `pc` states automatically

Raw `TLA+` is better when you want:

- a more abstract protocol model
- relation-heavy or set-heavy definitions
- a spec not tied to a program-like control flow

You are always reasoning about the generated TLA+ semantics in the end.

## 9. Abstraction and Refinement

The spec should preserve the decisions that matter and ignore the details that do not.

Good abstraction:

- replace payloads with symbolic tags
- use finite model values instead of large structured data
- represent "some worker" rather than all concrete worker IDs when symmetry applies
- model permission states, not API response bodies

Refinement means introducing implementation detail without violating the abstract spec.
The concrete design may have more variables and more steps, but it should not permit bad behaviors the abstract model excluded.

## 10. Common Semantic Mistakes

### Modeling implementation detail too early

If the first spec has real timestamps, full payloads, and production IDs, it is probably too concrete.

### Forgetting the environment

Networks drop messages. Humans deny approvals. Tools fail. Storage can lag.
If the environment is not modeled, the proof may be irrelevant.

### Overusing fairness

Do not use fairness to hide starvation or bad scheduling design.

### Treating actions like imperative code

An action is a mathematical constraint on the next state, not a block of executable statements.

### Leaving state under-specified

If you omit `UNCHANGED` clauses carelessly, you can accidentally allow nonsense transitions.

### Confusing deadlock with correctness

Deadlock is a checker concern, not the whole semantics.
Some models intentionally terminate. Others must not.
Make the intent explicit.

## 11. Practical Mental Model

When a user gives you a system description, immediately ask:

1. What are the state variables?
2. What transitions are allowed?
3. What actions belong to the environment?
4. What must never happen?
5. What must eventually happen?
6. What detail can be abstracted away without changing those answers?

If you can answer those six questions cleanly, you are already halfway to a useful TLA+ spec.
