#!/usr/bin/env bash
# TihonSpec Docs Synchronization
# Sync docs between parent workspace and child sub-workspaces

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SCRIPT_DIR/common-env.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common-env.sh" >&2
    exit 1
}

# JSON escape function
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# Default values
DRY_RUN="false"
FORCE="false"
ALL_SUB_WORKSPACES="false"
FROM_SUB_WORKSPACE=""
TO_SUB_WORKSPACE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            ALL_SUB_WORKSPACES="true"
            shift
            ;;
        --from-sub-workspace)
            FROM_SUB_WORKSPACE="$2"
            shift 2
            ;;
        --to-sub-workspace)
            TO_SUB_WORKSPACE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 --all|--from-sub-workspace NAME|--to-sub-workspace NAME [--dry-run] [--force]" >&2
            exit 1
            ;;
    esac
done

if [[ "$ALL_SUB_WORKSPACES" != "true" ]] && [[ -z "$FROM_SUB_WORKSPACE" ]] && [[ -z "$TO_SUB_WORKSPACE" ]]; then
    echo "ERROR: Specify --all, --from-sub-workspace NAME, or --to-sub-workspace NAME" >&2
    echo "" >&2
    echo "Usage:" >&2
    echo "  $0 --all                        # Sync all sub-workspaces to parent" >&2
    echo "  $0 --from-sub-workspace NAME    # Sync specific sub-workspace to parent" >&2
    echo "  $0 --to-sub-workspace NAME      # Sync parent shared docs to sub-workspace" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run    Preview changes without syncing" >&2
    echo "  --force      Overwrite existing files" >&2
    exit 1
fi

# Get current workspace config
DETECT_SCRIPT="$SCRIPT_DIR/detect-config.sh"
if [[ ! -f "$DETECT_SCRIPT" ]]; then
    echo "ERROR: detect-config.sh not found" >&2
    exit 1
fi

CURRENT_CONFIG=$(bash "$DETECT_SCRIPT" 2>/dev/null || echo '{}')
CONFIG_FOUND=$(echo "$CURRENT_CONFIG" | jq -r '.CONFIG_FOUND // false')

if [[ "$CONFIG_FOUND" != "true" ]]; then
    echo "ERROR: No .tihonspec.yaml found" >&2
    exit 1
fi

CURRENT_WORKSPACE_ROOT=$(echo "$CURRENT_CONFIG" | jq -r '.WORKSPACE_ROOT')
CURRENT_WORKSPACE_NAME=$(echo "$CURRENT_CONFIG" | jq -r '.WORKSPACE_NAME')
CURRENT_DOCS_PATH=$(echo "$CURRENT_CONFIG" | jq -r '.DOCS_PATH // "ai_docs"')
SYNC_BACKUP=$(echo "$CURRENT_CONFIG" | jq -r '.DOCS_SYNC_BACKUP // true')


# Backup file with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]] && [[ "$SYNC_BACKUP" == "true" ]]; then
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local backup="${file}.bak.${timestamp}"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "[dry-run] Would backup: $file -> $backup" >&2
        else
            cp "$file" "$backup"
            echo "Backed up: $file -> $backup" >&2
        fi
        echo "$backup"
    fi
}

# Sync single file
sync_file() {
    local source="$1"
    local target="$2"

    # Create target directory
    local target_dir=$(dirname "$target")
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] Would create dir: $target_dir" >&2
    else
        mkdir -p "$target_dir"
    fi

    # Check if target exists and differs
    if [[ -f "$target" ]]; then
        if diff -q "$source" "$target" >/dev/null 2>&1; then
            echo "[skip] Identical: $target" >&2
            return 0
        fi

        if [[ "$FORCE" != "true" ]] && [[ "$DIRECTION" == "from-parent" ]]; then
            echo "[skip] Child has file (use --force to override): $target" >&2
            return 0
        fi

        # Backup existing
        backup_file "$target"
    fi

    # Copy file
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[dry-run] Would copy: $source -> $target" >&2
    else
        cp "$source" "$target"
        echo "[sync] $source -> $target" >&2
    fi
}

# Sync from sub-workspace to parent workspace docs
sync_from_sub_workspace() {
    local sub_workspace_name="$1"
    local sub_workspaces
    sub_workspaces=$(echo "$CURRENT_CONFIG" | jq -r '.SUB_WORKSPACES // []')

    # Find sub-workspace by name
    local sub_workspace
    sub_workspace=$(echo "$sub_workspaces" | jq -r --arg name "$sub_workspace_name" '.[] | select(.name == $name)')

    if [[ -z "$sub_workspace" ]]; then
        echo "ERROR: Sub-workspace '$sub_workspace_name' not found" >&2
        local available
        available=$(echo "$sub_workspaces" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//')
        echo "Available: $available" >&2
        exit 1
    fi

    local sub_workspace_path=$(echo "$sub_workspace" | jq -r '.path')
    local sub_workspace_full_path="$CURRENT_WORKSPACE_ROOT/$sub_workspace_path"

    # Get sub-workspace's docs path from config
    local sub_workspace_config="$sub_workspace_full_path/.tihonspec/.tihonspec.yaml"
    local sub_workspace_docs_path="$CURRENT_DOCS_PATH"
    if [[ -f "$sub_workspace_config" ]]; then
        local config_docs_path
        config_docs_path=$(yq eval '.docs.path // empty' "$sub_workspace_config" 2>/dev/null)
        if [[ -n "$config_docs_path" ]]; then
            sub_workspace_docs_path="$config_docs_path"
        fi
    fi
    local sub_workspace_docs="$sub_workspace_full_path/$sub_workspace_docs_path"

    if [[ ! -d "$sub_workspace_docs" ]]; then
        echo "ERROR: No docs found for sub-workspace: $sub_workspace_name" >&2
        echo "Expected: $sub_workspace_docs" >&2
        exit 1
    fi

    local source_dir="$sub_workspace_docs"
    local target_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH/sub-workspaces/$sub_workspace_name"

    echo "Syncing sub-workspace: $sub_workspace_name" >&2

    local files_synced=0
    while IFS= read -r -d '' file; do
        local relative_path="${file#$source_dir/}"
        local target_file="$target_dir/$relative_path"
        sync_file "$file" "$target_file" && ((files_synced++)) || true
    done < <(find "$source_dir" -type f -print0 2>/dev/null)

    cat <<EOF
{
  "SUCCESS": true,
  "SUB_WORKSPACE": "$(json_escape "$sub_workspace_name")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": $files_synced,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Sync from parent workspace to sub-workspace
sync_to_sub_workspace() {
    local sub_workspace_name="$1"
    local sub_workspaces
    sub_workspaces=$(echo "$CURRENT_CONFIG" | jq -r '.SUB_WORKSPACES // []')

    # Find sub-workspace by name
    local sub_workspace
    sub_workspace=$(echo "$sub_workspaces" | jq -r --arg name "$sub_workspace_name" '.[] | select(.name == $name)')

    if [[ -z "$sub_workspace" ]]; then
        echo "ERROR: Sub-workspace '$sub_workspace_name' not found" >&2
        local available
        available=$(echo "$sub_workspaces" | jq -r '.[].name' | tr '\n' ', ' | sed 's/,$//')
        echo "Available: $available" >&2
        exit 1
    fi

    local sub_workspace_path=$(echo "$sub_workspace" | jq -r '.path')
    local sub_workspace_full_path="$CURRENT_WORKSPACE_ROOT/$sub_workspace_path"

    # Get sub-workspace's docs path from config
    local sub_workspace_config="$sub_workspace_full_path/.tihonspec/.tihonspec.yaml"
    local sub_workspace_docs_path="$CURRENT_DOCS_PATH"
    if [[ -f "$sub_workspace_config" ]]; then
        local config_docs_path
        config_docs_path=$(yq eval '.docs.path // empty' "$sub_workspace_config" 2>/dev/null)
        if [[ -n "$config_docs_path" ]]; then
            sub_workspace_docs_path="$config_docs_path"
        fi
    fi
    local target_dir="$sub_workspace_full_path/$sub_workspace_docs_path"

    # Source: parent's sub-workspaces/{name} folder (shared docs for this sub-workspace)
    local source_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH/sub-workspaces/$sub_workspace_name"

    if [[ ! -d "$source_dir" ]]; then
        echo "No shared docs found for sub-workspace: $sub_workspace_name" >&2
        echo "Expected: $source_dir" >&2
        cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "to-sub-workspace",
  "SUB_WORKSPACE": "$(json_escape "$sub_workspace_name")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": 0,
  "MESSAGE": "No shared docs found in parent",
  "DRY_RUN": $DRY_RUN
}
EOF
        return 0
    fi

    echo "Syncing to sub-workspace: $sub_workspace_name" >&2

    local files_synced=0
    while IFS= read -r -d '' file; do
        local relative_path="${file#$source_dir/}"
        local target_file="$target_dir/$relative_path"
        sync_file "$file" "$target_file" && ((files_synced++)) || true
    done < <(find "$source_dir" -type f -print0 2>/dev/null)

    cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "to-sub-workspace",
  "SUB_WORKSPACE": "$(json_escape "$sub_workspace_name")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": $files_synced,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Sync all sub-workspaces (from parent workspace)
sync_all_sub_workspaces() {
    local sub_workspaces
    sub_workspaces=$(echo "$CURRENT_CONFIG" | jq -r '.SUB_WORKSPACES // []')

    if [[ "$sub_workspaces" == "[]" ]] || [[ -z "$sub_workspaces" ]]; then
        echo "No sub-workspaces defined in workspace config" >&2
        cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "all",
  "MESSAGE": "No sub-workspaces defined",
  "SUB_WORKSPACES_SYNCED": 0
}
EOF
        return 0
    fi

    local sub_workspaces_synced=0
    local results="[]"

    # Iterate through sub-workspaces
    while IFS= read -r sub_workspace; do
        local sub_workspace_name=$(echo "$sub_workspace" | jq -r '.name')
        local sub_workspace_path=$(echo "$sub_workspace" | jq -r '.path')

        local sub_workspace_full_path="$CURRENT_WORKSPACE_ROOT/$sub_workspace_path"

        # Get sub-workspace's docs path from config FIRST (before checking directory)
        local sub_workspace_config="$sub_workspace_full_path/.tihonspec/.tihonspec.yaml"
        local sub_workspace_docs_path="$CURRENT_DOCS_PATH"  # Inherit from workspace by default
        if [[ -f "$sub_workspace_config" ]]; then
            local config_docs_path
            config_docs_path=$(yq eval '.docs.path // empty' "$sub_workspace_config" 2>/dev/null)
            if [[ -n "$config_docs_path" ]]; then
                sub_workspace_docs_path="$config_docs_path"
            fi
        fi
        local sub_workspace_docs="$sub_workspace_full_path/$sub_workspace_docs_path"

        # Check if sub-workspace has docs (using correct path from config)
        if [[ -d "$sub_workspace_docs" ]]; then

            local source_dir="$sub_workspace_docs"
            local target_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH/sub-workspaces/$sub_workspace_name"

            echo "Syncing sub-workspace: $sub_workspace_name" >&2

            local files_synced=0
            while IFS= read -r -d '' file; do
                local relative_path="${file#$source_dir/}"
                local target_file="$target_dir/$relative_path"
                sync_file "$file" "$target_file" && ((files_synced++)) || true
            done < <(find "$source_dir" -type f -print0 2>/dev/null)

            ((sub_workspaces_synced++)) || true
        else
            echo "[skip] No docs found for sub-workspace: $sub_workspace_name" >&2
        fi
    done < <(echo "$sub_workspaces" | jq -c '.[]')

    cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "all",
  "SUB_WORKSPACES_SYNCED": $sub_workspaces_synced,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Main execution
main() {
    echo "Workspace: $CURRENT_WORKSPACE_ROOT ($CURRENT_WORKSPACE_NAME)" >&2

    if [[ "$ALL_SUB_WORKSPACES" == "true" ]]; then
        sync_all_sub_workspaces
    elif [[ -n "$FROM_SUB_WORKSPACE" ]]; then
        sync_from_sub_workspace "$FROM_SUB_WORKSPACE"
    elif [[ -n "$TO_SUB_WORKSPACE" ]]; then
        sync_to_sub_workspace "$TO_SUB_WORKSPACE"
    fi
}

main
