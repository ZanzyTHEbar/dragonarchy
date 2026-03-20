# Linear Reference

## MCP Server

Server: `user-linear`

## Teams

| Team | ID | Scope |
|------|----|-------|
| ZenWriter | `4c8b4a6b-0632-4713-9ccb-a768043c1864` | Software ventures |
| NordicSkyPropulsion | `05269408-cd4a-45ae-a263-f3d6265b7813` | Hardware ventures |

## Active Projects

| Project | Team | Linear ID | Status |
|---------|------|-----------|--------|
| Cursor Rules Premium | ZenWriter | `587a397f-c9f9-4722-a774-c4e92f7bb380` | Active — ship Gumroad listing |
| MCP Memory Cloud | ZenWriter | `0f17de56-b838-45e6-8c7c-2a22eae4aab4` | Active — build cloud MVP |
| PetFilter Commercialization | NordicSkyPropulsion | `bb698f12-a5e9-491f-83e6-d3d7fac7120d` | Gated — awaiting Gate 1 |
| Offline-first Docs + Yjs Sync | ZenWriter | `85565c75-79a9-42f6-b672-cec12e9505c3` | Active — Zenwriter MVP |
| Alpha Engine: Cleanup | NordicSkyPropulsion | `713d103b-68d8-46d2-a310-9dae340084ec` | In Progress |
| Alpha Engine: Server Productionization | NordicSkyPropulsion | `df80cd12-7a32-4bec-b434-bf97e821a243` | Planned |
| MVP of Jetecu | NordicSkyPropulsion | `d82f056e-cb8b-40c7-a42b-c0d8dfe4dd96` | In Progress |
| DragonScale Agent Runtime | ZenWriter | `e39eec22-b8f0-4b5c-b97e-3dd9b2a44e20` | In Progress |

## Label Taxonomy

### Tier Labels (parent: "Tier")

| Label | Color | Meaning |
|-------|-------|---------|
| P0 | `#EB5757` | Immediate — this week |
| P1 | `#F2994A` | High — this quarter |
| P2 | `#F2C94C` | Medium — next quarter |

### Type Labels (parent: "Type")

| Label | Color | Meaning |
|-------|-------|---------|
| revenue | `#27AE60` | Directly generates revenue |
| gate | `#9B51E0` | Decision gate requiring evaluation |
| infrastructure | `#2F80ED` | Build/deploy infrastructure |

## Milestones

| Milestone | Project | Target Date |
|-----------|---------|-------------|
| Cloud MVP Launch | MCP Memory Cloud | 2026-05-20 |
| Gate 1: POC Greenlight | PetFilter Commercialization | 2026-05-20 |
| Gate 2: Prototype Greenlight | PetFilter Commercialization | 2026-08-20 |

## Common Tool Calls

### List issues for a project

```json
{
  "toolName": "list_issues",
  "arguments": { "project": "MCP Memory Cloud", "limit": 25 }
}
```

### Create an issue

```json
{
  "toolName": "create_issue",
  "arguments": {
    "title": "Add API key auth middleware",
    "team": "ZenWriter",
    "project": "MCP Memory Cloud",
    "priority": 1,
    "labels": ["P0", "infrastructure"],
    "assignee": "me",
    "description": "## Goal\n..."
  }
}
```

### Update issue status

```json
{
  "toolName": "update_issue",
  "arguments": { "id": "ZEN-132", "state": "In Progress" }
}
```

### Add a comment

```json
{
  "toolName": "create_comment",
  "arguments": { "issueId": "ZEN-132", "body": "Implemented auth middleware. PR ready." }
}
```
