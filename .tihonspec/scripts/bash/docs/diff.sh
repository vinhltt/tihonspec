#!/usr/bin/env bash
#
# diff.sh - Compare docs between workspace and sub-workspace
#
# Usage: diff.sh --sub-workspace NAME [--detailed]
#
# Compares files in sub-workspace docs with workspace docs.
# Used by /docs:diff and /docs:sync commands.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common-env.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common-env.sh" >&2
    exit 1
}

# JSON escape function
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

# Parse arguments
SUB_WORKSPACE_NAME=""
DETAILED="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sub-workspace)
            SUB_WORKSPACE_NAME="$2"
            shift 2
            ;;
        --detailed)
            DETAILED="true"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$SUB_WORKSPACE_NAME" ]]; then
    echo "ERROR: --sub-workspace NAME is required" >&2
    echo "Usage: $0 --sub-workspace NAME [--detailed]" >&2
    exit 1
fi

REPO_ROOT=$(get_repo_root)

# Get workspace config
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
DETECT_SCRIPT="$SCRIPT_DIR/../detect-config.sh"

if [[ -f "$DETECT_SCRIPT" ]]; then
    CONFIG_JSON=$(bash "$DETECT_SCRIPT" --sub-workspace "$SUB_WORKSPACE_NAME") || exit 1

    CONFIG_FOUND=$(echo "$CONFIG_JSON" | jq -r '.CONFIG_FOUND // false' 2>/dev/null)
    if [[ "$CONFIG_FOUND" == "true" ]]; then
        WORKSPACE_ROOT=$(echo "$CONFIG_JSON" | jq -r '.WORKSPACE_ROOT // empty' 2>/dev/null)
        DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.DOCS_PATH // "ai_docs"' 2>/dev/null)
        [[ -z "$WORKSPACE_ROOT" ]] && WORKSPACE_ROOT="$REPO_ROOT"

        TARGET_SUB_WORKSPACE=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE // empty' 2>/dev/null)
        if [[ -n "$TARGET_SUB_WORKSPACE" && "$TARGET_SUB_WORKSPACE" != "null" ]]; then
            TARGET_ROOT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE.root // empty' 2>/dev/null)
            TARGET_DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE.docs_path // empty' 2>/dev/null)
        fi

        ERROR=$(echo "$CONFIG_JSON" | jq -r '.ERROR // empty' 2>/dev/null)
        if [[ "$ERROR" == "sub_workspace_not_found" ]]; then
            AVAILABLE=$(echo "$CONFIG_JSON" | jq -r '.AVAILABLE_SUB_WORKSPACES | join(", ")' 2>/dev/null)
            echo "ERROR: Sub-workspace '$SUB_WORKSPACE_NAME' not found" >&2
            echo "Available: $AVAILABLE" >&2
            exit 1
        fi
    fi
fi

if [[ -z "$TARGET_ROOT" ]]; then
    echo "ERROR: Could not determine sub-workspace root for '$SUB_WORKSPACE_NAME'" >&2
    exit 1
fi

# Paths
WORKSPACE_DOCS="$WORKSPACE_ROOT/$DOCS_PATH"
SUB_WORKSPACE_DOCS="$TARGET_ROOT/$TARGET_DOCS_PATH"

# Check directories exist
if [[ ! -d "$WORKSPACE_DOCS" ]]; then
    echo "WARNING: Workspace docs directory not found: $WORKSPACE_DOCS" >&2
fi

if [[ ! -d "$SUB_WORKSPACE_DOCS" ]]; then
    echo "ERROR: Sub-workspace docs directory not found: $SUB_WORKSPACE_DOCS" >&2
    exit 1
fi

# Collect all unique file paths from both directories
declare -A ALL_FILES

# Scan workspace docs
if [[ -d "$WORKSPACE_DOCS" ]]; then
    while IFS= read -r -d '' file; do
        relative_path="${file#$WORKSPACE_DOCS/}"
        # Skip sub-workspaces folder and manager files
        if [[ "$relative_path" == sub-workspaces/* ]] || \
           [[ "$relative_path" == "document-manager.md" ]] || \
           [[ "$relative_path" == "custom-document-manager.md" ]]; then
            continue
        fi
        ALL_FILES["$relative_path"]="workspace"
    done < <(find "$WORKSPACE_DOCS" -type f -name "*.md" -print0 2>/dev/null)
fi

# Scan sub-workspace docs
if [[ -d "$SUB_WORKSPACE_DOCS" ]]; then
    while IFS= read -r -d '' file; do
        relative_path="${file#$SUB_WORKSPACE_DOCS/}"
        # Skip manager files
        if [[ "$relative_path" == "document-manager.md" ]] || \
           [[ "$relative_path" == "custom-document-manager.md" ]]; then
            continue
        fi
        if [[ -n "${ALL_FILES[$relative_path]:-}" ]]; then
            ALL_FILES["$relative_path"]="both"
        else
            ALL_FILES["$relative_path"]="sub_workspace"
        fi
    done < <(find "$SUB_WORKSPACE_DOCS" -type f -name "*.md" -print0 2>/dev/null)
fi

# Build diff results
DIFF_RESULTS="[]"
COUNT_NEW=0
COUNT_MODIFIED=0
COUNT_IDENTICAL=0
COUNT_WORKSPACE_ONLY=0

for file_path in "${!ALL_FILES[@]}"; do
    location="${ALL_FILES[$file_path]}"
    workspace_file="$WORKSPACE_DOCS/$file_path"
    sub_workspace_file="$SUB_WORKSPACE_DOCS/$file_path"

    status=""
    details=""
    diff_content=""

    case "$location" in
        "sub_workspace")
            # New in sub-workspace (not in workspace)
            status="new"
            details="Sub-workspace only"
            ((COUNT_NEW++)) || true
            ;;
        "workspace")
            # Only in workspace (not in sub-workspace)
            status="workspace_only"
            details="Workspace only"
            ((COUNT_WORKSPACE_ONLY++)) || true
            ;;
        "both")
            # Exists in both - compare content
            if diff -q "$workspace_file" "$sub_workspace_file" >/dev/null 2>&1; then
                status="identical"
                details="No changes"
                ((COUNT_IDENTICAL++)) || true
            else
                status="modified"
                # Get line diff counts
                diff_output=$(diff --suppress-common-lines "$workspace_file" "$sub_workspace_file" 2>/dev/null || true)
                added=$(echo "$diff_output" | grep -c '^>' 2>/dev/null || echo "0")
                removed=$(echo "$diff_output" | grep -c '^<' 2>/dev/null || echo "0")
                details="+$added -$removed lines"
                ((COUNT_MODIFIED++)) || true

                # Include diff content if detailed
                if [[ "$DETAILED" == "true" ]]; then
                    diff_content=$(diff -u "$workspace_file" "$sub_workspace_file" 2>/dev/null | head -50 || true)
                fi
            fi
            ;;
    esac

    # Add to results
    if [[ -n "$diff_content" ]]; then
        DIFF_RESULTS=$(echo "$DIFF_RESULTS" | jq \
            --arg path "$file_path" \
            --arg status "$status" \
            --arg details "$details" \
            --arg diff "$diff_content" \
            '. + [{path: $path, status: $status, details: $details, diff: $diff}]')
    else
        DIFF_RESULTS=$(echo "$DIFF_RESULTS" | jq \
            --arg path "$file_path" \
            --arg status "$status" \
            --arg details "$details" \
            '. + [{path: $path, status: $status, details: $details}]')
    fi
done

# Output JSON
cat <<EOF
{
  "SUB_WORKSPACE_NAME": "$(json_escape "$SUB_WORKSPACE_NAME")",
  "WORKSPACE_DOCS": "$(json_escape "$WORKSPACE_DOCS")",
  "SUB_WORKSPACE_DOCS": "$(json_escape "$SUB_WORKSPACE_DOCS")",
  "DETAILED": $DETAILED,
  "SUMMARY": {
    "new": $COUNT_NEW,
    "modified": $COUNT_MODIFIED,
    "identical": $COUNT_IDENTICAL,
    "workspace_only": $COUNT_WORKSPACE_ONLY,
    "total": $((COUNT_NEW + COUNT_MODIFIED + COUNT_IDENTICAL + COUNT_WORKSPACE_ONLY))
  },
  "FILES": $DIFF_RESULTS
}
EOF
