# Verification Workflow

This file covers how to move from a spec to useful evidence.
`TLC` is the default engine for finite, explicit-state verification. `Apalache` and `TLAPS` are complementary tools, not replacements for good modeling.

## 1. TLC in One Sentence

TLC enumerates concrete states of a finite model, checks invariants as it explores the state graph, and produces counterexample traces when properties fail.

## 2. How TLC Thinks

At a high level, TLC does this:

1. Generate all initial states satisfying `Init`
2. For each unexplored state, compute all successors satisfying `Next`
3. Check invariants and state constraints immediately
4. Record visited states to avoid re-exploring duplicates
5. If liveness is enabled, analyze cycles that can violate fairness or eventuality properties

The result is usually breadth-first style bug hunting with very strong feedback:

- short counterexample traces
- exact bad states
- explicit visibility into state growth

## 3. Executable Subset vs Mathematical Language

TLA+ is a rich mathematical language. TLC evaluates only the executable subset.

Engineering consequence:

- write ordinary mathematical specs freely at the design level
- when you want TLC to run them, keep constants finite and operators executable
- if something is not executable, either refactor the model or move to proof-oriented tooling

## 4. Standard Modeling Loop

### Step 1: Build a tiny finite instance

Start with absurdly small constants:

- `Agents = {a1, a2}`
- one or two resources
- one or two messages
- short bounded sequences

The first goal is not realism. The first goal is to make the model falsifiable.

### Step 2: Check `TypeOK`

`TypeOK` should be the first invariant.
If `TypeOK` fails, the model structure is broken before any behavioral property matters.

### Step 3: Check safety invariants

Typical order:

1. `TypeOK`
2. state-local safety invariants
3. relational invariants
4. only then liveness

### Step 4: Add liveness and fairness

Only after the state space is stable and safety bugs are fixed.

## 5. Reading a TLC Model Config

A typical `.cfg` file controls:

- `SPECIFICATION`
- `CONSTANTS`
- `INVARIANT`
- `PROPERTY`
- `SYMMETRY`
- `CONSTRAINT`
- `VIEW`

### Minimal example

```cfg
SPECIFICATION Spec
CONSTANTS
    Agents = {a1, a2}

INVARIANT
    TypeOK
    MutualExclusion
```

### Common additions

- `PROPERTY`: liveness or temporal properties
- `SYMMETRY`: reduces equivalent process permutations
- `CONSTRAINT`: trims unreachable or intentionally ignored states
- `VIEW`: collapses states that differ only in irrelevant detail

Use `CONSTRAINT` and `VIEW` carefully. They change what TLC explores and reports.

## 6. Commands and Tooling

The exact invocation depends on the extension or local install, but these are the usual CLI patterns:

```bash
java -cp tla2tools.jar tlc2.TLC Spec.tla
java -cp tla2tools.jar tlc2.TLC -config Spec.cfg Spec.tla
java -cp tla2tools.jar tlc2.TLC -deadlock -workers auto Spec.tla
java -cp tla2tools.jar tlc2.TLC -simulate num=1000 Spec.tla
java -cp tla2tools.jar tlc2.TLC -lncheck final Spec.tla
```

Useful flags and ideas:

- `-workers auto`: parallelize state exploration
- `-deadlock`: decide whether deadlock should be reported
- `-simulate`: fast random exploration for huge spaces
- `-lncheck final`: defer liveness checking until after the safety pass

The VS Code/Cursor TLA+ extension can handle the tool wiring if it is installed.

## 7. Interpreting TLC Output

The numbers matter.
Watch these signals:

- number of generated states
- number of distinct states
- queue size or frontier size
- diameter
- whether liveness checking started

### Healthy pattern

- state count grows, then stabilizes
- invariants hold
- no huge unexplained frontier blow-up

### Dangerous pattern

- distinct states grow explosively with tiny constants
- diameter stays small while width explodes
- tiny parameter increases cause orders-of-magnitude growth

That usually means the model is too wide, too concrete, or too nondeterministic.

## 8. Counterexample Handling

A TLC trace is not "tool noise". It is a design artifact.
Process it in this order:

1. Restate the violated property in plain English
2. Identify the first transition that makes recovery impossible
3. Decide whether the issue is:
   - a real design bug
   - a missing assumption
   - an over-strong property
   - an over-abstract model
4. Propose the smallest fix that preserves the intent of the model

### Counterexample discipline

- Do not patch the invariant to silence a trace you do not understand
- Do not add fairness to hide a safety bug
- Do not add constraints just to make TLC finish

## 9. State-Space Explosion: Practical Mitigations

Use these in roughly this order:

### Shrink domains

- smaller constants
- fewer agents
- fewer messages
- fewer possible statuses

### Collapse data

- replace payloads with model values
- collapse equivalent states
- keep only the information needed for the property

### Reduce ordering

- use sets instead of sequences when order does not matter
- use one representative resource when copies are symmetric

### Reduce atomic width

- split monster actions with `pc`
- break a huge step into multiple smaller labeled steps

### Add checker-aware reductions

- symmetry
- `VIEW`
- safe state constraints

Only after those should you consider switching from exhaustive search to simulation or symbolic tools.

## 10. When to Use Apalache

Use `Apalache` when:

- the model is still finite but too large for explicit-state TLC
- arithmetic or symbolic structure dominates
- you want bounded model checking or inductive invariant workflows

Typical invocation:

```bash
apalache-mc check --length=10 Spec.tla
```

Treat Apalache as a different engine with different strengths.
It does not rescue a badly abstracted model automatically.

## 11. When to Use TLAPS

Use `TLAPS` when:

- you need proof over unbounded sizes
- the property is beyond practical model checking
- the spec is mature enough that proof effort is justified

In practice:

- TLC finds bugs quickly
- Apalache stretches bounded reasoning farther
- TLAPS proves the theorems that search cannot finish

## 12. Recommended Engineering Sequence

For most serious systems:

1. Write the abstract model
2. Bound it tightly
3. Run TLC
4. Fix every safety counterexample
5. Add fairness carefully
6. Run liveness checks
7. If TLC still cannot scale, try Apalache
8. If the claim must hold generally, move mature lemmas into TLAPS

## 13. What to Report Back

A good verification report says:

- what was modeled
- what was intentionally omitted
- which constants were used
- which invariants and properties were checked
- whether the evidence is exhaustive, simulated, bounded-symbolic, or proved
- what the next scaling or refinement step should be

That makes the verification result useful to engineering, not just to the tool operator.
