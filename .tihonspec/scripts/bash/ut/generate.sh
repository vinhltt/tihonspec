#!/bin/bash
#
# generate.sh - Validate environment for /ut:generate command
#
# Usage: generate.sh <feature-id>
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
FEATURE_ID="$1"

if [ -z "$FEATURE_ID" ]; then
    echo "❌ Error: Feature ID required" >&2
    echo "Usage: $0 <feature-id>" >&2
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

# Define input paths
TEST_SPEC_FILE="$FEATURE_DIR/test-spec.md"
COVERAGE_FILE="$FEATURE_DIR/coverage-analysis.md"
PLAN_FILE="$FEATURE_DIR/test-plan.md"
UT_RULES_FILE="$REPO_ROOT/docs/rules/test/ut-rule.md"

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
  "REPO_ROOT": "$(json_escape "$REPO_ROOT")",
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
