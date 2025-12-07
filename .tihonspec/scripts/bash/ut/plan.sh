#!/bin/bash
#
# plan.sh - Validate environment for /ut:plan command
#
# Usage: plan.sh <feature-id> [--sub-workspace NAME] [--review] [--force] [--standalone]
#
# Options:
#   --sub-workspace NAME  Target specific sub-workspace
#   --review              Review existing plan
#   --force               Force overwrite existing files
#   --standalone          Skip feature spec requirement (write UT from codebase directly)
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
FEATURE_ID=""
SUB_WORKSPACE_NAME=""
REVIEW_MODE="false"
FORCE_MODE="false"
STANDALONE_MODE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sub-workspace)
            SUB_WORKSPACE_NAME="$2"
            shift 2
            ;;
        --review)
            REVIEW_MODE="true"
            shift
            ;;
        --force)
            FORCE_MODE="true"
            shift
            ;;
        --standalone)
            STANDALONE_MODE="true"
            shift
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
    echo "Usage: $0 <feature-id> [--sub-workspace NAME] [--review] [--force] [--standalone]" >&2
    echo "💡 Example: $0 aa-001" >&2
    echo "💡 Use --standalone to skip feature spec requirement (write UT from codebase directly)" >&2
    exit 1
fi

# Case-insensitive: convert to lowercase
FEATURE_ID=$(echo "$FEATURE_ID" | tr '[:upper:]' '[:lower:]')

# Get repository root (fallback)
REPO_ROOT=$(get_repo_root)

# Parse feature ID to get paths
parsed=$(parse_feature_id "$FEATURE_ID") || exit 1
IFS='|' read -r FOLDER TICKET FEATURE_DIR BRANCH_NAME <<< "$parsed"

# Get workspace config (hierarchical model) with sub-workspace targeting
WORKSPACE_ROOT="$REPO_ROOT"
DOCS_PATH="ai_docs"
TARGET_ROOT=""
TARGET_DOCS_PATH=""
DETECT_SCRIPT="$SCRIPT_DIR/../detect-config.sh"

if [[ -f "$DETECT_SCRIPT" ]]; then
    # Pass --sub-workspace flag if specified
    if [[ -n "$SUB_WORKSPACE_NAME" ]]; then
        CONFIG_JSON=$(bash "$DETECT_SCRIPT" --sub-workspace "$SUB_WORKSPACE_NAME") || exit 1
    else
        CONFIG_JSON=$(bash "$DETECT_SCRIPT") || exit 1
    fi

    CONFIG_FOUND=$(echo "$CONFIG_JSON" | jq -r '.CONFIG_FOUND // false' 2>/dev/null)
    if [[ "$CONFIG_FOUND" == "true" ]]; then
        WORKSPACE_ROOT=$(echo "$CONFIG_JSON" | jq -r '.WORKSPACE_ROOT // empty' 2>/dev/null)
        DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.DOCS_PATH // "ai_docs"' 2>/dev/null)
        [[ -z "$WORKSPACE_ROOT" ]] && WORKSPACE_ROOT="$REPO_ROOT"

        # Check for sub-workspace targeting
        TARGET_SUB_WORKSPACE=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE // empty' 2>/dev/null)
        if [[ -n "$TARGET_SUB_WORKSPACE" && "$TARGET_SUB_WORKSPACE" != "null" ]]; then
            TARGET_ROOT=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE.root // empty' 2>/dev/null)
            TARGET_DOCS_PATH=$(echo "$CONFIG_JSON" | jq -r '.TARGET_SUB_WORKSPACE.docs_path // empty' 2>/dev/null)
        fi

        # Check for error (sub-workspace not found)
        ERROR=$(echo "$CONFIG_JSON" | jq -r '.ERROR // empty' 2>/dev/null)
        if [[ "$ERROR" == "sub_workspace_not_found" ]]; then
            AVAILABLE=$(echo "$CONFIG_JSON" | jq -r '.AVAILABLE_SUB_WORKSPACES | join(", ")' 2>/dev/null)
            echo "❌ Error: Sub-workspace '$SUB_WORKSPACE_NAME' not found" >&2
            echo "💡 Available sub-workspaces: $AVAILABLE" >&2
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

# Define output paths (using output root)
SPEC_FILE="$FEATURE_DIR/spec.md"
TEST_SPEC_FILE="$FEATURE_DIR/test-spec.md"
COVERAGE_FILE="$FEATURE_DIR/coverage-analysis.md"
PLAN_FILE="$FEATURE_DIR/test-plan.md"
UT_RULES_FILE="$OUTPUT_ROOT/$OUTPUT_DOCS_PATH/rules/test/ut-rule.md"

# Check feature directory and spec.md existence
HAS_FEATURE_DIR="false"
HAS_SPEC_FILE="false"
NEEDS_STANDALONE_PROMPT="false"

if [ -d "$FEATURE_DIR" ]; then
    HAS_FEATURE_DIR="true"
fi

if [ -f "$SPEC_FILE" ]; then
    HAS_SPEC_FILE="true"
fi

# Auto-detect: if no spec but not explicitly standalone, signal AI to ask user
if [ "$STANDALONE_MODE" != "true" ] && [ "$HAS_SPEC_FILE" != "true" ]; then
    NEEDS_STANDALONE_PROMPT="true"
    # Create feature dir for output files
    if [ ! -d "$FEATURE_DIR" ]; then
        mkdir -p "$FEATURE_DIR"
        HAS_FEATURE_DIR="true"
    fi
fi

# If explicit standalone mode, ensure dir exists
if [ "$STANDALONE_MODE" == "true" ] && [ ! -d "$FEATURE_DIR" ]; then
    mkdir -p "$FEATURE_DIR"
    HAS_FEATURE_DIR="true"
fi

# Check existing files
MODE="create"
EXISTING_FILES=""

if [ -f "$TEST_SPEC_FILE" ]; then
    EXISTING_FILES="$EXISTING_FILES test-spec.md"
    MODE="exists"
fi

if [ -f "$PLAN_FILE" ]; then
    EXISTING_FILES="$EXISTING_FILES test-plan.md"
    MODE="exists"
fi

# Check if UT rules exist
HAS_UT_RULES="false"
if [ -f "$UT_RULES_FILE" ]; then
    HAS_UT_RULES="true"
fi

# Output JSON for AI (with escaped paths for Windows compatibility)
cat <<EOF
{
  "WORKSPACE_ROOT": "$(json_escape "$WORKSPACE_ROOT")",
  "FEATURE_ID": "$(json_escape "$FEATURE_ID")",
  "FEATURE_DIR": "$(json_escape "$FEATURE_DIR")",
  "SPEC_FILE": "$(json_escape "$SPEC_FILE")",
  "TEST_SPEC_FILE": "$(json_escape "$TEST_SPEC_FILE")",
  "COVERAGE_FILE": "$(json_escape "$COVERAGE_FILE")",
  "PLAN_FILE": "$(json_escape "$PLAN_FILE")",
  "UT_RULES_FILE": "$(json_escape "$UT_RULES_FILE")",
  "HAS_UT_RULES": $HAS_UT_RULES,
  "HAS_SPEC_FILE": $HAS_SPEC_FILE,
  "NEEDS_STANDALONE_PROMPT": $NEEDS_STANDALONE_PROMPT,
  "EXISTING_FILES": "$(json_escape "$EXISTING_FILES")",
  "MODE": "$MODE",
  "REVIEW_MODE": $REVIEW_MODE,
  "FORCE_MODE": $FORCE_MODE,
  "STANDALONE_MODE": $STANDALONE_MODE
}
EOF
