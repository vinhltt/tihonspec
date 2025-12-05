---
description: List all projects in the current workspace
---

## Purpose

Display all projects configured in the workspace with their status and paths.

## Usage

```
/project.list
```

## Execution Steps

### Step 1: Find Workspace

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output
3. If no workspace found:
   - "Not in a workspace. Run from workspace root or project directory."
   - STOP

### Step 2: Load Workspace Config

1. Navigate to workspace root
2. Read `.tihonspec/tihonspec.yaml`
3. Extract `projects` array

### Step 3: Scan Projects

For each project in `projects` array:

1. Check if path exists
2. Check if `.tihonspec/tihonspec.yaml` exists in project
3. If project config exists:
   - Load and merge with workspace
   - Get metadata, rules count
4. Calculate status:
   - "configured" = has project config
   - "inherited" = no project config (uses workspace)
   - "missing" = path doesn't exist

### Step 4: Output Table

```
Workspace: {workspace_name}
Root: {workspace_path}

Projects:
┌──────────────┬─────────────────────┬────────────┬───────────┬──────────┐
│ Name         │ Path                │ Language   │ Framework │ Status   │
├──────────────┼─────────────────────┼────────────┼───────────┼──────────┤
│ Frontend     │ apps/frontend       │ typescript │ react     │ configured │
│ Backend      │ apps/backend        │ python     │ fastapi   │ configured │
│ Shared       │ packages/shared     │ typescript │ -         │ inherited  │
│ Mobile       │ apps/mobile         │ -          │ -         │ missing    │
└──────────────┴─────────────────────┴────────────┴───────────┴──────────┘

Summary: 4 projects (2 configured, 1 inherited, 1 missing)

Commands:
  /project.init     - Initialize project config in current directory
  /feature.specify  - Start feature specification
```

### Step 5: Handle Edge Cases

| Scenario | Output |
|----------|--------|
| No projects array | "No projects defined in workspace" |
| Empty projects | "Workspace has no projects configured" |
| Not in workspace | "Not in a workspace directory" |
