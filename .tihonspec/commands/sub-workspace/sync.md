# /sub-workspace:sync (Deprecated)

> **DEPRECATED**: This command has been moved to `/docs:sync`.
>
> Use the new commands instead:
> - `/docs:sync --from-sub-workspace NAME` - Sync sub-workspace to parent
> - `/docs:sync --to-sub-workspace NAME` - Sync parent to sub-workspace
> - `/docs:sync --all` - Sync all sub-workspaces

## Migration Guide

| Old Command | New Command |
|-------------|-------------|
| `/sub-workspace:sync to-parent` | `/docs:sync --from-sub-workspace {NAME}` |
| `/sub-workspace:sync from-parent` | `/docs:sync --to-sub-workspace {NAME}` |
| `/sub-workspace:sync all` | `/docs:sync --all` |

## Why Changed?

1. **Consistency**: All docs-related commands now under `/docs:*`
2. **Explicit naming**: `--from-sub-workspace` and `--to-sub-workspace` are clearer
3. **Diff preview**: New sync shows diff before syncing (safer)
4. **Run from workspace**: All sync operations run from workspace root

## See Also

- `/docs:sync` - New sync command with diff preview
- `/docs:diff` - Compare docs without syncing
- `/docs:index` - Generate document index
