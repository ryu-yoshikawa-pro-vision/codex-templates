# PROJECT_CONTEXT update: implementation_worker

## Summary
- Added `implementation_worker` as a consumer-facing workspace-write subagent for small, parent-approved implementation tasks.
- Kept existing `code_researcher`, `implementation_researcher`, and `test_investigator` as read-only investigation agents.
- Updated source context to distinguish read-only investigation agents from the scoped writable implementation worker.

## Safety boundary
- `implementation_worker` is only for small, scoped changes after the parent agent has fixed the plan, target files, change scope, and prohibited operations.
- File deletion, rename, move, git mutation, delete / rename patch operations, and scope expansion remain forbidden.
- Writable subagents should be used one at a time by default.
