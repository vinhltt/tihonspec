---
description: List all sub-workspaces in the current workspace
---

## Purpose

Display all sub-workspaces configured in the workspace with their status and paths.

## Usage

```
/sub-workspace.list
```

## Execution Steps

### Step 1: Find Workspace

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output
3. If no workspace found:
   - "Not in a workspace. Run from workspace root or sub-workspace directory."
   - STOP

### Step 2: Load Workspace Config

1. Navigate to workspace root
2. Read `.tihonspec/.tihonspec.yaml`
3. Extract `sub-workspaces` array

### Step 3: Scan Sub-workspaces

For each sub-workspace in `sub-workspaces` array:

1. Check if path exists
2. Check if `.tihonspec/.tihonspec.yaml` exists in sub-workspace
3. If sub-workspace config exists:
   - Load and merge with workspace
   - Get metadata, rules count
4. Calculate status:
   - "configured" = has sub-workspace config
   - "inherited" = no sub-workspace config (uses workspace)
   - "missing" = path doesn't exist

### Step 4: Output Table

```
Workspace: {workspace_name}
Root: {workspace_path}

Sub-workspaces:
┌──────────────┬─────────────────────┬────────────┬───────────┬──────────┐
│ Name         │ Path                │ Language   │ Framework │ Status   │
├──────────────┼─────────────────────┼────────────┼───────────┼──────────┤
│ Frontend     │ apps/frontend       │ typescript │ react     │ configured │
│ Backend      │ apps/backend        │ python     │ fastapi   │ configured │
│ Shared       │ packages/shared     │ typescript │ -         │ inherited  │
│ Mobile       │ apps/mobile         │ -          │ -         │ missing    │
└──────────────┴─────────────────────┴────────────┴───────────┴──────────┘

Summary: 4 sub-workspaces (2 configured, 1 inherited, 1 missing)

Commands:
  /sub-workspace.init     - Initialize sub-workspace config in current directory
  /feature.specify        - Start feature specification
```

### Step 5: Handle Edge Cases

| Scenario | Output |
|----------|--------|
| No sub-workspaces array | "No sub-workspaces defined in workspace" |
| Empty sub-workspaces | "Workspace has no sub-workspaces configured" |
| Not in workspace | "Not in a workspace directory" |
