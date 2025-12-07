---
description: Initialize a new sub-workspace configuration in the current directory
---

## Purpose

Create a new `.tihonspec.yaml` configuration file for the current sub-workspace.

## Usage

```
/sub-workspace.init [sub-workspace-name]
```

## Execution Steps

### Step 1: Determine Sub-workspace Name

1. If argument provided: use as sub-workspace name
2. If no argument: use current directory name
3. Convert to lowercase, replace spaces with hyphens

### Step 2: Check Existing Config

1. Check if `.tihonspec/.tihonspec.yaml` exists
2. If exists:
   - Show current config summary
   - Ask: "Config exists. Overwrite? (y/n)"
   - If no: STOP

### Step 3: Detect Sub-workspace Type

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output
3. If workspace config found above:
   - Type = "sub-workspace" (child of workspace)
   - Inherit workspace settings
4. If no workspace:
   - Type = "sub-workspace" (standalone)

### Step 4: Auto-detect Metadata

Scan current directory for:

| File | Detection |
|------|-----------|
| `package.json` | language: typescript/javascript |
| `tsconfig.json` | language: typescript |
| `pyproject.toml` | language: python |
| `go.mod` | language: go |
| `Cargo.toml` | language: rust |

Framework detection:
| Pattern | Framework |
|---------|-----------|
| `next.config.*` | nextjs |
| `vite.config.*` | vite |
| `vue.config.*` | vue |
| `angular.json` | angular |

### Step 5: Generate Config

Create `.tihonspec/.tihonspec.yaml`:

```yaml
version: "1.0"
name: "{sub_workspace_name}"
type: "sub-workspace"

docs:
  path: "ai_docs"
  rules: []

metadata:
  language: "{detected_language}"
  framework: "{detected_framework}"
  package_manager: "{detected_pm}"
  test_framework: ""

rules: []

commands:
  test: ""
  build: ""
  lint: ""
```

### Step 6: Create Docs Directory

Use DOCS_PATH from workspace config if available, otherwise default to `ai_docs`:

1. Create `{DOCS_PATH}/` if not exists
2. Create `{DOCS_PATH}/rules.md` from template (use `.tihonspec/examples/rules-template.md`)

### Step 7: Output

```
Sub-workspace initialized: {sub_workspace_name}

Created:
  - .tihonspec/.tihonspec.yaml
  - {DOCS_PATH}/
  - {DOCS_PATH}/rules.md

Detected:
  - Language: {language}
  - Framework: {framework}

Next steps:
  1. Edit .tihonspec/.tihonspec.yaml to configure sub-workspace
  2. Edit {DOCS_PATH}/rules.md to add sub-workspace rules
  3. Run /sub-workspace.list to verify workspace integration
```
