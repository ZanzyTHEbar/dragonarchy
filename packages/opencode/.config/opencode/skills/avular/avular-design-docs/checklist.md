# Design Review Checklist

Use this checklist to decide which sections belong in the design.

## Always Consider

- Objective
- Scope and out-of-scope
- Impact on other components
- Requirements and assumptions
- Proposed design
- Verification strategy

## Include If Relevant

### Interfaces

Include if the change adds or changes:

- APIs
- ROS topics, services, or messages
- file formats
- communication protocols
- external dependencies

### Diagrams

Include if the design is hard to review in text alone:

- component diagram
- sequence diagram
- state diagram
- package or file structure

### Risks And Error Handling

Include if failure behavior influences the architecture, UX, or test strategy.

### Alternatives

Include if there are multiple viable options and the choice needs stakeholder review.

### Performance, Security, Maintainability

Include only when these qualities meaningfully affect the design decision.

## Exclude By Default

- planning detail that does not affect the technical review
- exhaustive documentation of obvious implementation details
- sections copied from checklists without design value
