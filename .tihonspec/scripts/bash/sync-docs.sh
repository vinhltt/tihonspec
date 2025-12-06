#!/usr/bin/env bash
# TihonSpec Docs Synchronization
# Sync docs between parent workspace and child projects

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
DIRECTION=""
DRY_RUN="false"
FORCE="false"
ALL_PROJECTS="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --to-parent)
            DIRECTION="to-parent"
            shift
            ;;
        --from-parent)
            DIRECTION="from-parent"
            shift
            ;;
        --all)
            ALL_PROJECTS="true"
            DIRECTION="to-parent"
            shift
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
            echo "Usage: $0 --to-parent|--from-parent|--all [--dry-run] [--force]" >&2
            exit 1
            ;;
    esac
done

if [[ -z "$DIRECTION" ]]; then
    echo "ERROR: Direction required (--to-parent, --from-parent, or --all)" >&2
    echo "Usage: $0 --to-parent|--from-parent|--all [--dry-run] [--force]" >&2
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

# Find parent workspace (walk up from current workspace root)
find_parent_workspace() {
    local current_dir="$(dirname "$CURRENT_WORKSPACE_ROOT")"
    local depth=0
    local max_depth=10

    while [[ "$current_dir" != "/" ]] && [[ $depth -lt $max_depth ]]; do
        local config_file="$current_dir/.tihonspec/.tihonspec.yaml"
        if [[ -f "$config_file" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
        ((depth++)) || true
    done

    return 1
}

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

# Sync to parent (push all docs)
sync_to_parent() {
    local parent_root="$1"
    local parent_docs_path="ai_docs"

    # Get parent's docs path from config
    local parent_config="$parent_root/.tihonspec/.tihonspec.yaml"
    if [[ -f "$parent_config" ]]; then
        parent_docs_path=$(yq eval '.docs.path // "ai_docs"' "$parent_config" 2>/dev/null || echo "ai_docs")
    fi

    local source_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH"
    local target_dir="$parent_root/$parent_docs_path/projects/$CURRENT_WORKSPACE_NAME"

    if [[ ! -d "$source_dir" ]]; then
        echo "ERROR: Source docs directory not found: $source_dir" >&2
        return 1
    fi

    echo "Syncing: $source_dir -> $target_dir" >&2

    local files_synced=0
    local files_skipped=0
    local backups_created=0

    # Find and sync all files
    while IFS= read -r -d '' file; do
        local relative_path="${file#$source_dir/}"
        local target_file="$target_dir/$relative_path"

        if sync_file "$file" "$target_file"; then
            ((files_synced++)) || true
        else
            ((files_skipped++)) || true
        fi
    done < <(find "$source_dir" -type f -print0 2>/dev/null)

    # Output JSON result
    cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "to-parent",
  "PROJECT_NAME": "$(json_escape "$CURRENT_WORKSPACE_NAME")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": $files_synced,
  "FILES_SKIPPED": $files_skipped,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Sync from parent (pull/bootstrap)
sync_from_parent() {
    local parent_root="$1"
    local parent_docs_path="ai_docs"

    # Get parent's docs path from config
    local parent_config="$parent_root/.tihonspec/.tihonspec.yaml"
    if [[ -f "$parent_config" ]]; then
        parent_docs_path=$(yq eval '.docs.path // "ai_docs"' "$parent_config" 2>/dev/null || echo "ai_docs")
    fi

    local source_dir="$parent_root/$parent_docs_path/projects/$CURRENT_WORKSPACE_NAME"
    local target_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH"

    if [[ ! -d "$source_dir" ]]; then
        echo "No docs found in parent for project: $CURRENT_WORKSPACE_NAME" >&2
        cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "from-parent",
  "PROJECT_NAME": "$(json_escape "$CURRENT_WORKSPACE_NAME")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": 0,
  "FILES_SKIPPED": 0,
  "MESSAGE": "No docs found in parent",
  "DRY_RUN": $DRY_RUN
}
EOF
        return 0
    fi

    echo "Syncing: $source_dir -> $target_dir" >&2

    local files_synced=0
    local files_skipped=0

    # Find and sync all files
    while IFS= read -r -d '' file; do
        local relative_path="${file#$source_dir/}"
        local target_file="$target_dir/$relative_path"

        if sync_file "$file" "$target_file"; then
            ((files_synced++)) || true
        else
            ((files_skipped++)) || true
        fi
    done < <(find "$source_dir" -type f -print0 2>/dev/null)

    # Output JSON result
    cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "from-parent",
  "PROJECT_NAME": "$(json_escape "$CURRENT_WORKSPACE_NAME")",
  "SOURCE": "$(json_escape "$source_dir")",
  "TARGET": "$(json_escape "$target_dir")",
  "FILES_SYNCED": $files_synced,
  "FILES_SKIPPED": $files_skipped,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Sync all projects (from parent workspace)
sync_all_projects() {
    local projects
    projects=$(echo "$CURRENT_CONFIG" | jq -r '.PROJECTS // []')

    if [[ "$projects" == "[]" ]] || [[ -z "$projects" ]]; then
        echo "No projects defined in workspace config" >&2
        cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "all",
  "MESSAGE": "No projects defined",
  "PROJECTS_SYNCED": 0
}
EOF
        return 0
    fi

    local projects_synced=0
    local results="[]"

    # Iterate through projects
    while IFS= read -r project; do
        local project_name=$(echo "$project" | jq -r '.name')
        local project_path=$(echo "$project" | jq -r '.path')

        local project_full_path="$CURRENT_WORKSPACE_ROOT/$project_path"
        local project_docs="$project_full_path/ai_docs"

        # Check if project has docs
        if [[ -d "$project_docs" ]]; then
            # Get project's docs path from config
            local project_config="$project_full_path/.tihonspec/.tihonspec.yaml"
            local project_docs_path="ai_docs"
            if [[ -f "$project_config" ]]; then
                project_docs_path=$(yq eval '.docs.path // "ai_docs"' "$project_config" 2>/dev/null || echo "ai_docs")
            fi
            project_docs="$project_full_path/$project_docs_path"

            local source_dir="$project_docs"
            local target_dir="$CURRENT_WORKSPACE_ROOT/$CURRENT_DOCS_PATH/projects/$project_name"

            echo "Syncing project: $project_name" >&2

            local files_synced=0
            while IFS= read -r -d '' file; do
                local relative_path="${file#$source_dir/}"
                local target_file="$target_dir/$relative_path"
                sync_file "$file" "$target_file" && ((files_synced++)) || true
            done < <(find "$source_dir" -type f -print0 2>/dev/null)

            ((projects_synced++)) || true
        else
            echo "[skip] No docs found for project: $project_name" >&2
        fi
    done < <(echo "$projects" | jq -c '.[]')

    cat <<EOF
{
  "SUCCESS": true,
  "DIRECTION": "all",
  "PROJECTS_SYNCED": $projects_synced,
  "DRY_RUN": $DRY_RUN
}
EOF
}

# Main execution
main() {
    if [[ "$ALL_PROJECTS" == "true" ]]; then
        sync_all_projects
        return
    fi

    # Find parent workspace
    local parent_root
    if ! parent_root=$(find_parent_workspace); then
        echo "ERROR: No parent workspace found" >&2
        cat <<EOF
{
  "SUCCESS": false,
  "ERROR": "No parent workspace found"
}
EOF
        exit 1
    fi

    echo "Parent workspace: $parent_root" >&2
    echo "Current workspace: $CURRENT_WORKSPACE_ROOT ($CURRENT_WORKSPACE_NAME)" >&2

    case "$DIRECTION" in
        to-parent)
            sync_to_parent "$parent_root"
            ;;
        from-parent)
            sync_from_parent "$parent_root"
            ;;
    esac
}

main
