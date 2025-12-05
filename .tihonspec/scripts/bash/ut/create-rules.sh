#!/bin/bash
#
# create-rules.sh - Validate environment for /ut:create-rules command
#
# Usage: create-rules.sh [--project NAME]
#
# This script validates environment and outputs paths.
# Framework detection and test scanning handled by AI via prompt.

set -eo pipefail

# Source environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common-env.sh" 2>/dev/null || {
    echo "❌ Error: Failed to load common-env.sh" >&2
    exit 1
}

# JSON escape function for safe output
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Parse arguments
PROJECT_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Get repository root (fallback)
REPO_ROOT=$(get_repo_root)

# Get workspace config (hierarchical model) with project targeting
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
PROJECTS_JSON="[]"
DETECT_SCRIPT="$SCRIPT_DIR/../detect-config.sh"

if [[ -f "$DETECT_SCRIPT" ]]; then
    # Pass --project flag if specified
    if [[ -n "$PROJECT_NAME" ]]; then
        CONFIG_JSON=$(bash "$DETECT_SCRIPT" --project "$PROJECT_NAME" 2>/dev/null || echo '{}')
    else
        CONFIG_JSON=$(bash "$DETECT_SCRIPT" 2>/dev/null || echo '{}')
    fi

    CONFIG_FOUND=$(echo "$CONFIG_JSON" | jq -r '.CONFIG_FOUND // false' 2>/dev/null)
    if [[ "$CONFIG_FOUND" == "true" ]]; then
        WORKSPACE_ROOT=$(echo "$CONFIG_JSON" | jq -r '.WORKSPACE_ROOT // empty' 2>/dev/null)
        DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.DOCS_PATH // "ai_docs"' 2>/dev/null)
        PROJECTS_JSON=$(echo "$CONFIG_JSON" | jq -c '.PROJECTS // []' 2>/dev/null)
        [[ -z "$WORKSPACE_ROOT" ]] && WORKSPACE_ROOT="$REPO_ROOT"

        # Check for project targeting
        TARGET_PROJECT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT // empty' 2>/dev/null)
        if [[ -n "$TARGET_PROJECT" && "$TARGET_PROJECT" != "null" ]]; then
            TARGET_ROOT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT.root // empty' 2>/dev/null)
            TARGET_DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT.docs_path // empty' 2>/dev/null)
        fi

        # Check for error (project not found)
        ERROR=$(echo "$CONFIG_JSON" | jq -r '.ERROR // empty' 2>/dev/null)
        if [[ "$ERROR" == "project_not_found" ]]; then
            AVAILABLE=$(echo "$CONFIG_JSON" | jq -r '.AVAILABLE_PROJECTS | join(", ")' 2>/dev/null)
            echo "❌ Error: Project '$PROJECT_NAME' not found" >&2
            echo "💡 Available projects: $AVAILABLE" >&2
            exit 1
        fi
    fi
fi

# Determine output root (project root or workspace root)
OUTPUT_ROOT="$WORKSPACE_ROOT"
OUTPUT_DOCS_PATH="$DOCS_PATH"
if [[ -n "$TARGET_ROOT" ]]; then
    OUTPUT_ROOT="$TARGET_ROOT"
    OUTPUT_DOCS_PATH="$TARGET_DOCS_PATH"
fi

# Define output paths (using target root and docs path)
RULES_DIR="$OUTPUT_ROOT/$OUTPUT_DOCS_PATH/rules/test"
RULES_FILE="$RULES_DIR/ut-rule.md"
TEMPLATE_FILE="$REPO_ROOT/.tihonspec/templates/ut-rule-template.md"

# Check if feature root exists
if [ ! -d "$REPO_ROOT/.tihonspec" ]; then
    echo "❌ Error: .tihonspec directory not found" >&2
    echo "💡 Tip: Initialize TihonSpec with setup command" >&2
    exit 1
fi

# Check if template exists and is readable
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: UT rule template not found: $TEMPLATE_FILE" >&2
    echo "💡 Tip: Restore with 'git checkout .tihonspec/templates/ut-rule-template.md'" >&2
    exit 1
fi

if [ ! -r "$TEMPLATE_FILE" ]; then
    echo "❌ Error: Cannot read template file: $TEMPLATE_FILE" >&2
    echo "💡 Tip: Check file permissions" >&2
    exit 1
fi

# Check existing rules
EXISTING_RULES=""
MODE="create"
if [ -f "$RULES_FILE" ]; then
    EXISTING_RULES="$RULES_FILE"
    MODE="exists"
fi

# Create rules directory
mkdir -p "$RULES_DIR"

# Output JSON for AI (with escaped paths for Windows compatibility)
cat <<EOF
{
  "WORKSPACE_ROOT": "$(json_escape "$WORKSPACE_ROOT")",
  "DOCS_PATH": "$(json_escape "$DOCS_PATH")",
  "OUTPUT_ROOT": "$(json_escape "$OUTPUT_ROOT")",
  "OUTPUT_DOCS_PATH": "$(json_escape "$OUTPUT_DOCS_PATH")",
  "RULES_DIR": "$(json_escape "$RULES_DIR")",
  "RULES_FILE": "$(json_escape "$RULES_FILE")",
  "TEMPLATE_FILE": "$(json_escape "$TEMPLATE_FILE")",
  "EXISTING_RULES": "$(json_escape "$EXISTING_RULES")",
  "MODE": "$MODE",
  "PROJECT_NAME": "$(json_escape "$PROJECT_NAME")",
  "PROJECTS": $PROJECTS_JSON
}
EOF
