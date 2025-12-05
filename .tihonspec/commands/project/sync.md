# /project.sync

Synchronize documentation between parent workspace and child projects.

## Usage

### Push docs to parent workspace
```bash
/project.sync to-parent
```

### Pull docs from parent (bootstrap)
```bash
/project.sync from-parent
```

### Sync all child projects (from parent)
```bash
/project.sync all
```

### Options
- `--dry-run` - Show what would happen without making changes
- `--force` - Override existing files (with backup)

## Script

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/../../scripts/bash/sync-docs.sh"

# Map command to script args
case "$1" in
    to-parent)
        bash "$SYNC_SCRIPT" --to-parent ${2:+$2} ${3:+$3}
        ;;
    from-parent)
        bash "$SYNC_SCRIPT" --from-parent ${2:+$2} ${3:+$3}
        ;;
    all)
        bash "$SYNC_SCRIPT" --all ${2:+$2} ${3:+$3}
        ;;
    *)
        echo "Usage: /project.sync <to-parent|from-parent|all> [--dry-run] [--force]"
        exit 1
        ;;
esac
```

## Examples

### Sync current project docs to parent
```
$ /project.sync to-parent
Syncing: /workspace/apps/frontend/ai_docs -> /workspace/ai_docs/projects/frontend
[sync] rules/test/ut-rule.md
[sync] specs/api-spec.md
{
  "SUCCESS": true,
  "FILES_SYNCED": 2
}
```

### Preview changes first
```
$ /project.sync to-parent --dry-run
[dry-run] Would copy: rules/test/ut-rule.md -> ai_docs/projects/frontend/rules/test/ut-rule.md
```

### Bootstrap new project from parent
```
$ /project.sync from-parent
Syncing: /workspace/ai_docs/projects/frontend -> /workspace/apps/frontend/ai_docs
[sync] rules/test/ut-rule.md
```
