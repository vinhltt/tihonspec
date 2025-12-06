#!/bin/bash
#
# check-rules.sh - Validate UT rules existence
#
# Usage: check-rules.sh [--project NAME]
#
# Checks if ut-rule.md exists and parses basic info.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common-env.sh" 2>/dev/null || {
    echo "❌ Error: Failed to load common-env.sh" >&2
    exit 1
}

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

REPO_ROOT=$(get_repo_root)

# Get workspace config with project targeting
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
PROJECTS_JSON="[]"
DETECT_SCRIPT="$SCRIPT_DIR/../detect-config.sh"

if [[ -f "$DETECT_SCRIPT" ]]; then
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

        TARGET_PROJECT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT // empty' 2>/dev/null)
        if [[ -n "$TARGET_PROJECT" && "$TARGET_PROJECT" != "null" ]]; then
            TARGET_ROOT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT.root // empty' 2>/dev/null)
            TARGET_DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.TARGET_PROJECT.docs_path // empty' 2>/dev/null)
        fi

        ERROR=$(echo "$CONFIG_JSON" | jq -r '.ERROR // empty' 2>/dev/null)
        if [[ "$ERROR" == "project_not_found" ]]; then
            AVAILABLE=$(echo "$CONFIG_JSON" | jq -r '.AVAILABLE_PROJECTS | join(", ")' 2>/dev/null)
            echo "❌ Error: Project '$PROJECT_NAME' not found" >&2
            echo "💡 Available: $AVAILABLE" >&2
            exit 1
        fi
    fi
fi

OUTPUT_ROOT="$WORKSPACE_ROOT"
OUTPUT_DOCS_PATH="$DOCS_PATH"
if [[ -n "$TARGET_ROOT" ]]; then
    OUTPUT_ROOT="$TARGET_ROOT"
    OUTPUT_DOCS_PATH="$TARGET_DOCS_PATH"
fi

RULES_FILE="$OUTPUT_ROOT/$OUTPUT_DOCS_PATH/rules/test/ut-rule.md"

# Check existence and parse info
EXISTS="false"
FRAMEWORK=""
COVERAGE_TARGET=""

if [[ -f "$RULES_FILE" ]]; then
    EXISTS="true"
    # Parse basic info from rules file
    FRAMEWORK=$(grep -m1 -i "framework" "$RULES_FILE" 2>/dev/null | sed 's/.*[Ff]ramework[[:space:]]*:[[:space:]]*//' | sed 's/[*#]//g' | head -1 || echo "")
    COVERAGE_TARGET=$(grep -m1 -i "coverage" "$RULES_FILE" 2>/dev/null | sed 's/.*[Cc]overage[[:space:]]*:[[:space:]]*//' | sed 's/[*#]//g' | head -1 || echo "80%")
fi

cat <<EOF
{
  "RULES_FILE": "$(json_escape "$RULES_FILE")",
  "EXISTS": $EXISTS,
  "FRAMEWORK": "$(json_escape "$FRAMEWORK")",
  "COVERAGE_TARGET": "$(json_escape "$COVERAGE_TARGET")",
  "OUTPUT_ROOT": "$(json_escape "$OUTPUT_ROOT")",
  "PROJECT_NAME": "$(json_escape "$PROJECT_NAME")",
  "PROJECTS": $PROJECTS_JSON
}
EOF
