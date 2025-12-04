#!/bin/bash
#
# auto.sh - Validate environment for /ut:auto command
#
# Usage: auto.sh <feature-id> [--skip-run] [--plan-only] [--force]
#
# This script validates environment and outputs paths.
# Workflow orchestration handled by AI via prompt.

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
SKIP_RUN="false"
PLAN_ONLY="false"
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-run)
            SKIP_RUN="true"
            shift
            ;;
        --plan-only)
            PLAN_ONLY="true"
            shift
            ;;
        --force)
            FORCE="true"
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
    echo "Usage: $0 <feature-id> [--skip-run] [--plan-only] [--force]" >&2
    echo "💡 Example: $0 aa-001" >&2
    exit 1
fi

# Case-insensitive: convert to lowercase
FEATURE_ID=$(echo "$FEATURE_ID" | tr '[:upper:]' '[:lower:]')

# Get repository root
REPO_ROOT=$(get_repo_root)

# Parse feature ID to get paths
parsed=$(parse_feature_id "$FEATURE_ID") || exit 1
IFS='|' read -r FOLDER TICKET FEATURE_DIR BRANCH_NAME <<< "$parsed"

# Define paths (YAGNI: only what's needed for new simplified workflow)
SPEC_FILE="$FEATURE_DIR/spec.md"
PLAN_FILE="$FEATURE_DIR/test-plan.md"
UT_RULES_FILE="$REPO_ROOT/docs/rules/test/ut-rule.md"

# Validate feature directory exists
if [ ! -d "$FEATURE_DIR" ]; then
    echo "❌ Error: Feature directory not found: $FEATURE_DIR" >&2
    echo "💡 Tip: Run /feature:specify $FEATURE_ID first" >&2
    exit 1
fi

# Validate spec.md exists
if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ Error: spec.md not found: $SPEC_FILE" >&2
    echo "💡 Tip: Run /feature:specify $FEATURE_ID first" >&2
    exit 1
fi

# Check existing artifacts (YAGNI: only ut-rules and test-plan)
HAS_UT_RULES="false"
HAS_PLAN="false"

if [ -f "$UT_RULES_FILE" ]; then
    HAS_UT_RULES="true"
fi

if [ -f "$PLAN_FILE" ]; then
    HAS_PLAN="true"
fi

# Output JSON for AI (with escaped paths for Windows compatibility)
cat <<EOF
{
  "REPO_ROOT": "$(json_escape "$REPO_ROOT")",
  "FEATURE_ID": "$(json_escape "$FEATURE_ID")",
  "FEATURE_DIR": "$(json_escape "$FEATURE_DIR")",
  "SPEC_FILE": "$(json_escape "$SPEC_FILE")",
  "PLAN_FILE": "$(json_escape "$PLAN_FILE")",
  "UT_RULES_FILE": "$(json_escape "$UT_RULES_FILE")",
  "HAS_UT_RULES": $HAS_UT_RULES,
  "HAS_PLAN": $HAS_PLAN,
  "SKIP_RUN": $SKIP_RUN,
  "PLAN_ONLY": $PLAN_ONLY,
  "FORCE": $FORCE
}
EOF
