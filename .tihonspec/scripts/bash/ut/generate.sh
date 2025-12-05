#!/bin/bash
#
# generate.sh - Validate environment for /ut:generate command
#
# Usage: generate.sh <feature-id> [--project NAME]
#
# This script validates environment and outputs paths.
# Test generation logic handled by AI via prompt.

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
FEATURE_ID=""
PROJECT_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        *)
            if [ -z "$FEATURE_ID" ]; then
                FEATURE_ID="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$FEATURE_ID" ]; then
    echo "❌ Error: Feature ID required" >&2
    echo "Usage: $0 <feature-id> [--project NAME]" >&2
    echo "💡 Example: $0 aa-001" >&2
    exit 1
fi

# Case-insensitive: convert to lowercase
FEATURE_ID=$(echo "$FEATURE_ID" | tr '[:upper:]' '[:lower:]')

# Get repository root (fallback)
REPO_ROOT=$(get_repo_root)

# Parse feature ID to get paths
parsed=$(parse_feature_id "$FEATURE_ID") || exit 1
IFS='|' read -r FOLDER TICKET FEATURE_DIR BRANCH_NAME <<< "$parsed"

# Get workspace config (hierarchical model) with project targeting
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
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

# Define input paths (using output root)
TEST_SPEC_FILE="$FEATURE_DIR/test-spec.md"
COVERAGE_FILE="$FEATURE_DIR/coverage-analysis.md"
PLAN_FILE="$FEATURE_DIR/test-plan.md"
UT_RULES_FILE="$OUTPUT_ROOT/$OUTPUT_DOCS_PATH/rules/test/ut-rule.md"

# Validate feature directory exists
if [ ! -d "$FEATURE_DIR" ]; then
    echo "❌ Error: Feature directory not found: $FEATURE_DIR" >&2
    echo "💡 Tip: Run /feature:specify $FEATURE_ID first" >&2
    exit 1
fi

# Validate test-plan.md exists (required)
if [ ! -f "$PLAN_FILE" ]; then
    echo "❌ Error: test-plan.md not found: $PLAN_FILE" >&2
    echo "💡 Tip: Run /ut:plan $FEATURE_ID first" >&2
    exit 1
fi

# Validate ut-rule.md exists (required)
if [ ! -f "$UT_RULES_FILE" ]; then
    echo "❌ Error: UT rules not found: $UT_RULES_FILE" >&2
    echo "💡 Tip: Run /ut:create-rules first" >&2
    exit 1
fi

# Check optional files
HAS_TEST_SPEC="false"
HAS_COVERAGE="false"

if [ -f "$TEST_SPEC_FILE" ]; then
    HAS_TEST_SPEC="true"
fi

if [ -f "$COVERAGE_FILE" ]; then
    HAS_COVERAGE="true"
fi

# Output JSON for AI (with escaped paths for Windows compatibility)
cat <<EOF
{
  "WORKSPACE_ROOT": "$(json_escape "$WORKSPACE_ROOT")",
  "FEATURE_ID": "$(json_escape "$FEATURE_ID")",
  "FEATURE_DIR": "$(json_escape "$FEATURE_DIR")",
  "PLAN_FILE": "$(json_escape "$PLAN_FILE")",
  "TEST_SPEC_FILE": "$(json_escape "$TEST_SPEC_FILE")",
  "COVERAGE_FILE": "$(json_escape "$COVERAGE_FILE")",
  "UT_RULES_FILE": "$(json_escape "$UT_RULES_FILE")",
  "HAS_TEST_SPEC": $HAS_TEST_SPEC,
  "HAS_COVERAGE": $HAS_COVERAGE
}
EOF
