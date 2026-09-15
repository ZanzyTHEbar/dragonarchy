---
description: List currently available commands, tools, skills, agents, and workflow actions
---

# `/actions`

Inventory what is actually available in the current environment and help the user choose the fastest viable next move.

Include only capabilities that are currently configured or discoverable. Group the response by commands, tools, skills, agents, modes, and constraints when useful. Mark capabilities that depend on authentication, external services, user approval, or repository context. If the user provides a narrow context, filter the inventory instead of dumping everything.

User context: $ARGUMENTS

Do not invent tools, actions, integrations, or stale workflow names.
