# TihonSpec Configuration Guide

## Quick Start

Create `.tihonspec/.tihonspec.yaml` in your project root:

```yaml
version: "1.0"
name: "my-project"

docs:
  path: "ai_docs"
```

That's it! TihonSpec will now use `ai_docs/` for all documentation.

---

## Configuration Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Config version (always `"1.0"`) |
| `name` | string | Project/workspace name |

### Optional Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `docs.path` | string | `"ai_docs"` | Path to docs folder |
| `docs.sync.backup` | boolean | `true` | Create backup before override |
| `docs.sync.exclude` | array | `[]` | Glob patterns to exclude from sync |
| `projects` | array | `[]` | Child projects (for parent workspaces) |
| `metadata` | object | `{}` | Custom metadata |

---

## Examples

### Minimal Config (Standalone Project)

```yaml
version: "1.0"
name: "my-api"

docs:
  path: "ai_docs"
```

### Workspace with Multiple Projects

```yaml
version: "1.0"
name: "my-workspace"

docs:
  path: "ai_docs"

projects:
  - name: "frontend"
    path: "apps/frontend"

  - name: "backend"
    path: "apps/backend"

  - name: "shared-lib"
    path: "packages/shared"
```

### Custom Docs Path

```yaml
version: "1.0"
name: "legacy-project"

docs:
  path: ".docs"           # Hidden folder
  # or
  path: "documentation"   # Custom name
  # or
  path: "docs/ai"         # Nested path
```

### With Sync Exclusions

```yaml
version: "1.0"
name: "my-project"

docs:
  path: "ai_docs"
  sync:
    backup: true
    exclude:
      - "*.draft.md"      # Exclude draft files
      - ".local/**"       # Exclude local-only docs
      - "tmp/**"          # Exclude temp files
```

### With Metadata

```yaml
version: "1.0"
name: "enterprise-app"

docs:
  path: "ai_docs"

metadata:
  team: "platform"
  owner: "john@example.com"
  language: "typescript"
  framework: "react"
```

---

## Directory Structure

### Standalone Project

```
my-project/
├── .tihonspec/
│   └── .tihonspec.yaml
├── ai_docs/                    # docs.path
│   ├── rules/
│   │   └── test/
│   │       └── ut-rule.md
│   └── specs/
│       └── api-spec.md
└── src/
```

### Workspace with Child Projects

```
my-workspace/
├── .tihonspec/
│   └── .tihonspec.yaml          # Parent config
├── ai_docs/                    # Parent docs
│   ├── architecture.md         # Workspace-level docs
│   ├── business-overview.md
│   └── projects/               # Synced from children
│       ├── frontend/
│       │   └── rules/test/ut-rule.md
│       └── backend/
│           └── rules/test/ut-rule.md
│
├── apps/
│   ├── frontend/               # Child workspace
│   │   ├── .tihonspec/
│   │   │   └── .tihonspec.yaml
│   │   └── ai_docs/            # Child's own docs
│   │       └── rules/test/ut-rule.md
│   │
│   └── backend/                # Child workspace
│       ├── .tihonspec/
│       │   └── .tihonspec.yaml
│       └── ai_docs/
│           └── rules/test/ut-rule.md
│
└── packages/
    └── shared/
        ├── .tihonspec/
        │   └── .tihonspec.yaml
        └── ai_docs/
```

---

## Sync Commands

### Push docs to parent workspace

```bash
# From child project directory
/project.sync to-parent
```

### Pull docs from parent (bootstrap)

```bash
# From child project directory
/project.sync from-parent
```

### Sync all projects (from parent)

```bash
# From parent workspace directory
/project.sync all
```

### Options

- `--dry-run` - Preview changes without making them
- `--force` - Override existing files (with backup)

---

## Config Discovery

TihonSpec finds config by walking up from current directory:

```
/workspace/apps/frontend/src/components/Button.tsx
                              ↑ Start here
/workspace/apps/frontend/src/components/  (no config)
/workspace/apps/frontend/src/             (no config)
/workspace/apps/frontend/                 ← Found! .tihonspec/.tihonspec.yaml
```

The nearest `.tihonspec.yaml` determines the current workspace context.

---

## FAQ

### Q: Do I need a config file?

No. Without config, TihonSpec uses defaults:
- Docs path: `ai_docs`
- Sync backup: enabled

### Q: What's the difference between workspace and project?

None! In the hierarchical model, every config is a workspace. A "project" is just a workspace without child projects defined.

### Q: How do I disable sync for a project?

Either:
1. Don't add it to parent's `projects[]` list
2. Exclude its docs with `sync.exclude` patterns

### Q: Can I have nested workspaces?

Yes! Each folder with `.tihonspec/.tihonspec.yaml` is its own workspace.

```
company/                  # Level 1 workspace
├── team-a/               # Level 2 workspace
│   └── service-x/        # Level 3 workspace
```

### Q: Where are rules stored?

In your workspace's docs folder:
```
{workspace}/{docs.path}/rules/test/ut-rule.md
```

Example: `my-project/ai_docs/rules/test/ut-rule.md`

### Q: How does sync work?

- **to-parent**: Copies ALL files from `{child}/ai_docs/` to `{parent}/ai_docs/projects/{child-name}/`
- **from-parent**: Copies files from `{parent}/ai_docs/projects/{child-name}/` to `{child}/ai_docs/`
- Backups are created automatically before overriding existing files

---

## Project Targeting

### Overview

When working in a multi-project workspace, use `--project` flag to target a specific project:

```bash
/ut:create-rules --project frontend
```

This outputs rules to the project's docs folder instead of workspace root:
- **With flag**: `apps/frontend/ai_docs/rules/test/ut-rule.md`
- **Without flag**: `ai_docs/rules/test/ut-rule.md` (workspace level)

### Usage

All UT commands support `--project NAME`:

```bash
# Create rules for specific project
/ut:create-rules --project backend

# Plan tests for project
/ut:plan feature-001 --project frontend

# Generate tests
/ut:generate feature-001 --project backend

# Auto workflow
/ut:auto feature-001 --project frontend
```

### Auto-Detection

When running commands from within a project directory, TihonSpec auto-detects the project:

```
# CWD: /workspace/apps/frontend/src
$ /ut:create-rules

# Auto-detected: frontend
# Output: apps/frontend/ai_docs/rules/test/ut-rule.md
```

### Project Configuration

Each project can have its own docs path:

```yaml
# Parent workspace: .tihonspec/.tihonspec.yaml
version: "1.0"
name: "my-workspace"

docs:
  path: "ai_docs"

projects:
  - name: "frontend"
    path: "apps/frontend"
    docs:
      path: "ai_docs"      # Custom docs path for this project

  - name: "backend"
    path: "apps/backend"
    # Inherits parent's docs.path (ai_docs)
```

### Error Handling

When project not found:

```
❌ Error: Project 'foo' not found
💡 Available projects: frontend, backend, shared-lib
```

### FAQ: Project Targeting

#### Q: What if I run without --project in multi-project workspace?

If CWD is inside a project path → auto-detect and use that project.
Otherwise → use workspace root (default behavior).

#### Q: Can I override auto-detection?

Yes, `--project` flag always takes priority:

```bash
# CWD: /workspace/apps/frontend/src
$ /ut:create-rules --project backend

# Uses backend, not frontend (despite CWD)
```

#### Q: How do I list available projects?

Run any UT script without `--project` from workspace root:

```bash
$ bash .tihonspec/scripts/bash/ut/create-rules.sh
# JSON output includes PROJECTS array
```
