# Issue tracker

Issues for this repo live on Gitea at `https://git.deadzone.lol/Wizzard/void-zenkernel`. All reads and writes go through the `gitea` MCP server. curl is only for what the MCP cannot express, using the ambient git credential helper.

- Read issue: `mcp__gitea__issue_read`
- Create, comment, label, assign, close: `mcp__gitea__issue_write`
- List: `mcp__gitea__list_issues` (filter by label)
- Labels: `mcp__gitea__label_read`, `mcp__gitea__label_write`

PRs as a request surface: off.

## Wayfinding operations

Used by `/wayfinder`. The map is a single issue with child issues as tickets.

- **Map**: the open issue labelled `wayfinder:map`.
- **Child ticket**: an issue whose body starts with `Part of #<map>`. Labelled `wayfinder:<type>` (`research`, `prototype`, `grilling`, `task`). Claimed by assigning to `Wizzard`.
- **Blocking**: Gitea native issue dependencies, set via `POST /api/v1/repos/Wizzard/void-zenkernel/issues/<child>/dependencies` with body `{"owner":"Wizzard","repo":"void-zenkernel","index":<blocker>}` (no MCP tool exists for this). Mirrored as a `Blocked by: #n, #n` line at the top of the child body so the frontier is readable without the API.
- **Frontier query**: `mcp__gitea__list_issues` state open, drop tickets with an assignee or with an open issue in their `Blocked by` line. First in map order wins.
- **Claim**: `issue_write` update with `assignees: ["Wizzard"]`, before any other work.
- **Resolve**: `issue_write` add_comment with the answer, `issue_write` update state closed, then append a context pointer to the map's Decisions-so-far.
