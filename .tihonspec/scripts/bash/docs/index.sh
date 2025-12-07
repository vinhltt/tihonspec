#!/usr/bin/env bash
#
# index.sh - Scan docs directory and output file list JSON
#
# Usage: index.sh [--sub-workspace NAME] [--full]
#
# Scans all files in {docs.path}/ and outputs JSON for AI to process.
# Used by /docs:index command.

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
FULL_REBUILD="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sub-workspace)
            SUB_WORKSPACE_NAME="$2"
            shift 2
            ;;
        --full)
            FULL_REBUILD="true"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

REPO_ROOT=$(get_repo_root)

# Get workspace config with sub-workspace targeting
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
SUB_WORKSPACES_JSON="[]"
DETECT_SCRIPT="$SCRIPT_DIR/../detect-config.sh"

if [[ -f "$DETECT_SCRIPT" ]]; then
    if [[ -n "$SUB_WORKSPACE_NAME" ]]; then
        CONFIG_JSON=$(bash "$DETECT_SCRIPT" --sub-workspace "$SUB_WORKSPACE_NAME") || exit 1
    else
        CONFIG_JSON=$(bash "$DETECT_SCRIPT") || exit 1
    fi

    CONFIG_FOUND=$(echo "$CONFIG_JSON" | jq -r '.CONFIG_FOUND // false' 2>/dev/null)
    if [[ "$CONFIG_FOUND" == "true" ]]; then
        WORKSPACE_ROOT=$(echo "$CONFIG_JSON" | jq -r '.WORKSPACE_ROOT // empty' 2>/dev/null)
        DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.DOCS_PATH // "ai_docs"' 2>/dev/null)
        SUB_WORKSPACES_JSON=$(echo "$CONFIG_JSON" | jq -c '.SUB_WORKSPACES // []' 2>/dev/null)
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

# Determine output root (sub-workspace root or workspace root)
OUTPUT_ROOT="$WORKSPACE_ROOT"
OUTPUT_DOCS_PATH="$DOCS_PATH"
if [[ -n "$TARGET_ROOT" ]]; then
    OUTPUT_ROOT="$TARGET_ROOT"
    OUTPUT_DOCS_PATH="$TARGET_DOCS_PATH"
fi

# Paths
DOCS_DIR="$OUTPUT_ROOT/$OUTPUT_DOCS_PATH"
MANAGER_FILE="$DOCS_DIR/document-manager.md"

# Check if docs directory exists
if [[ ! -d "$DOCS_DIR" ]]; then
    echo "ERROR: Docs directory not found: $DOCS_DIR" >&2
    echo "Create the directory or check your configuration." >&2
    exit 1
fi

# Check if document-manager.md exists
HAS_MANAGER="false"
if [[ -f "$MANAGER_FILE" ]]; then
    HAS_MANAGER="true"
fi

# Scan all files in docs directory (excluding document-manager.md and custom-document-manager.md)
FILES_JSON="[]"
while IFS= read -r -d '' file; do
    relative_path="${file#$DOCS_DIR/}"

    # Skip manager files
    if [[ "$relative_path" == "document-manager.md" ]] || [[ "$relative_path" == "custom-document-manager.md" ]]; then
        continue
    fi

    # Get file info
    file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    file_modified=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null || echo "0")

    # Add to JSON array
    FILES_JSON=$(echo "$FILES_JSON" | jq --arg path "$relative_path" --arg size "$file_size" --arg mod "$file_modified" \
        '. + [{path: $path, size: ($size | tonumber), modified: ($mod | tonumber)}]')
done < <(find "$DOCS_DIR" -type f -name "*.md" -print0 2>/dev/null)

# Count files
FILE_COUNT=$(echo "$FILES_JSON" | jq 'length')

# Determine mode
MODE="create"
if [[ "$HAS_MANAGER" == "true" ]]; then
    if [[ "$FULL_REBUILD" == "true" ]]; then
        MODE="full_rebuild"
    else
        MODE="incremental"
    fi
fi

# Output JSON
cat <<EOF
{
  "DOCS_DIR": "$(json_escape "$DOCS_DIR")",
  "MANAGER_FILE": "$(json_escape "$MANAGER_FILE")",
  "HAS_MANAGER": $HAS_MANAGER,
  "MODE": "$MODE",
  "FULL_REBUILD": $FULL_REBUILD,
  "FILE_COUNT": $FILE_COUNT,
  "FILES": $FILES_JSON,
  "OUTPUT_ROOT": "$(json_escape "$OUTPUT_ROOT")",
  "SUB_WORKSPACE_NAME": "$(json_escape "$SUB_WORKSPACE_NAME")",
  "SUB_WORKSPACES": $SUB_WORKSPACES_JSON
}
EOF
