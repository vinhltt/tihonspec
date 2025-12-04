#!/bin/bash
#
# auto.sh - Validate environment for /ut:auto command
#
# Usage: auto.sh <feature-id> [--skip-run] [--plan-only] [--force]
#
# This script validates environment and outputs paths.
# Workflow orchestration handled by AI via prompt.

set -e

# Source environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common-env.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common-env.sh" >&2
    exit 1
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
    echo "ERROR: Feature ID required" >&2
    echo "Usage: $0 <feature-id> [--skip-run] [--plan-only] [--force]" >&2
    echo "Example: $0 pref-001" >&2
    exit 1
fi

# Case-insensitive: convert to lowercase
FEATURE_ID=$(echo "$FEATURE_ID" | tr '[:upper:]' '[:lower:]')

# Get repository root
REPO_ROOT=$(get_repo_root)

# Parse feature ID to get paths
parsed=$(parse_feature_id "$FEATURE_ID") || exit 1
IFS='|' read -r FOLDER TICKET FEATURE_DIR BRANCH_NAME <<< "$parsed"

# Define paths
SPEC_FILE="$FEATURE_DIR/spec.md"
TEST_SPEC_FILE="$FEATURE_DIR/test-spec.md"
COVERAGE_FILE="$FEATURE_DIR/coverage-analysis.md"
PLAN_FILE="$FEATURE_DIR/test-plan.md"
UT_RULES_FILE="$REPO_ROOT/docs/rules/test/ut-rule.md"

# Validate feature directory exists
if [ ! -d "$FEATURE_DIR" ]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    exit 1
fi

# Validate spec.md exists
if [ ! -f "$SPEC_FILE" ]; then
    echo "ERROR: spec.md not found: $SPEC_FILE" >&2
    echo "Run /feature.tihonspec $FEATURE_ID first" >&2
    exit 1
fi

# Check existing artifacts
HAS_UT_RULES="false"
HAS_TEST_SPEC="false"
HAS_COVERAGE="false"
HAS_PLAN="false"

if [ -f "$UT_RULES_FILE" ]; then
    HAS_UT_RULES="true"
fi

if [ -f "$TEST_SPEC_FILE" ]; then
    HAS_TEST_SPEC="true"
fi

if [ -f "$COVERAGE_FILE" ]; then
    HAS_COVERAGE="true"
fi

if [ -f "$PLAN_FILE" ]; then
    HAS_PLAN="true"
fi

# Output JSON for AI
cat <<EOF
{
  "REPO_ROOT": "$REPO_ROOT",
  "FEATURE_ID": "$FEATURE_ID",
  "FEATURE_DIR": "$FEATURE_DIR",
  "SPEC_FILE": "$SPEC_FILE",
  "TEST_SPEC_FILE": "$TEST_SPEC_FILE",
  "COVERAGE_FILE": "$COVERAGE_FILE",
  "PLAN_FILE": "$PLAN_FILE",
  "UT_RULES_FILE": "$UT_RULES_FILE",
  "HAS_UT_RULES": $HAS_UT_RULES,
  "HAS_TEST_SPEC": $HAS_TEST_SPEC,
  "HAS_COVERAGE": $HAS_COVERAGE,
  "HAS_PLAN": $HAS_PLAN,
  "SKIP_RUN": $SKIP_RUN,
  "PLAN_ONLY": $PLAN_ONLY,
  "FORCE": $FORCE
}
EOF
