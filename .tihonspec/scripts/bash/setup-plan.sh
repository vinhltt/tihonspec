#!/usr/bin/env bash

set -e

# Parse command line arguments
# Usage: setup-plan.sh <task-id> [--json]
JSON_MODE=false
TASK_ID=""

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 <task-id> [--json]"
            echo ""
            echo "Arguments:"
            echo "  <task-id>  Required. The task ID (e.g., pref-001, feature/aa-123)"
            echo ""
            echo "Options:"
            echo "  --json    Output results in JSON format"
            echo "  --help    Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 pref-001 --json"
            echo "  $0 feature/aa-123"
            exit 0
            ;;
        *)
            # First non-flag argument is task_id
            if [[ -z "$TASK_ID" ]]; then
                TASK_ID="$arg"
            fi
            ;;
    esac
done

# Validate task_id is provided
if [[ -z "$TASK_ID" ]]; then
    echo "❌ Error: task_id is required" >&2
    echo "Usage: $0 <task-id> [--json]" >&2
    echo "Example: $0 pref-001 --json" >&2
    exit 1
fi

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get all paths and variables with explicit task_id
eval $(get_feature_paths "$TASK_ID") || exit 1

# Note: Branch check removed - parallel workflows enabled via explicit task_id

# Ensure the feature directory exists
mkdir -p "$FEATURE_DIR"

# Copy plan template if it exists
TEMPLATE="$REPO_ROOT/$TIHONSPEC_SPECS_ROOT/templates/plan-template.md"
if [[ -f "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$IMPL_PLAN"
    echo "Copied plan template to $IMPL_PLAN"
else
    echo "Warning: Plan template not found at $TEMPLATE"
    # Create a basic plan file if template doesn't exist
    touch "$IMPL_PLAN"
fi

# Output results
if $JSON_MODE; then
    printf '{"TASK_ID":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","FEATURE_DIR":"%s","HAS_GIT":"%s"}\n' \
        "$TASK_ID" "$FEATURE_SPEC" "$IMPL_PLAN" "$FEATURE_DIR" "$HAS_GIT"
else
    echo "TASK_ID: $TASK_ID"
    echo "FEATURE_SPEC: $FEATURE_SPEC"
    echo "IMPL_PLAN: $IMPL_PLAN"
    echo "FEATURE_DIR: $FEATURE_DIR"
    echo "HAS_GIT: $HAS_GIT"
fi

