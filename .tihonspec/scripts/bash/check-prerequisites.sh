#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh <task-id> [OPTIONS]
#
# ARGUMENTS:
#   <task-id>           Required. The task ID (e.g., pref-001, feature/aa-123)
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-tasks     Require tasks.md to exist (for implementation phase)
#   --include-tasks     Include tasks.md in AVAILABLE_DOCS list
#   --paths-only        Only output path variables (no validation)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"TASK_ID":"...", "FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: TASK_ID:... \n FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n TASK_ID: ... \n FEATURE_DIR: ... etc.

set -e

# Check for required tools
check_required_tools() {
    local missing_tools=()

    if ! command -v yq &>/dev/null; then
        missing_tools+=("yq")
    fi

    if ! command -v jq &>/dev/null; then
        missing_tools+=("jq")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo "ERROR: Missing required tools: ${missing_tools[*]}" >&2
        echo "" >&2
        echo "Install instructions:" >&2
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                yq)
                    echo "  yq:" >&2
                    echo "    macOS:   brew install yq" >&2
                    echo "    Linux:   wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && chmod +x /usr/local/bin/yq" >&2
                    echo "    Windows: choco install yq" >&2
                    ;;
                jq)
                    echo "  jq:" >&2
                    echo "    macOS:   brew install jq" >&2
                    echo "    Linux:   apt-get install jq" >&2
                    echo "    Windows: choco install jq" >&2
                    ;;
            esac
        done
        return 1
    fi
    return 0
}

# Run tool check early (before parsing arguments)
if ! check_required_tools; then
    exit 1
fi

# Parse command line arguments
JSON_MODE=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false
TASK_ID=""

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            ;;
        --paths-only)
            PATHS_ONLY=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh <task-id> [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

ARGUMENTS:
  <task-id>           Required. The task ID (e.g., pref-001, feature/aa-123)

OPTIONS:
  --json              Output in JSON format
  --require-tasks     Require tasks.md to exist (for implementation phase)
  --include-tasks     Include tasks.md in AVAILABLE_DOCS list
  --paths-only        Only output path variables (no prerequisite validation)
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh pref-001 --json

  # Check implementation prerequisites (plan.md + tasks.md required)
  ./check-prerequisites.sh pref-001 --json --require-tasks --include-tasks

  # Get feature paths only (no validation)
  ./check-prerequisites.sh pref-001 --paths-only

EOF
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
    echo "Usage: $0 <task-id> [--json] [--require-tasks] [--include-tasks] [--paths-only]" >&2
    echo "Example: $0 pref-001 --json" >&2
    exit 1
fi

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get feature paths with explicit task_id
eval $(get_feature_paths "$TASK_ID") || exit 1

# Note: Branch check removed - parallel workflows enabled via explicit task_id

# If paths-only mode, output paths and exit (support JSON + paths-only combined)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        printf '{"TASK_ID":"%s","REPO_ROOT":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
            "$TASK_ID" "$REPO_ROOT" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    else
        echo "TASK_ID: $TASK_ID"
        echo "REPO_ROOT: $REPO_ROOT"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    exit 0
fi

# Validate required directories and files
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /feature.tihonspec first to create the feature structure." >&2
    exit 1
fi

if [[ ! -f "$IMPL_PLAN" ]]; then
    echo "ERROR: plan.md not found in $FEATURE_DIR" >&2
    echo "Run /feature.plan first to create the implementation plan." >&2
    exit 1
fi

# Check for tasks.md if required
if $REQUIRE_TASKS && [[ ! -f "$TASKS" ]]; then
    echo "ERROR: tasks.md not found in $FEATURE_DIR" >&2
    echo "Run /feature.tasks first to create the task list." >&2
    exit 1
fi

# Build list of available documents
docs=()

# Always check these optional docs
[[ -f "$RESEARCH" ]] && docs+=("research.md")
[[ -f "$DATA_MODEL" ]] && docs+=("data-model.md")

# Check contracts directory (only if it exists and has files)
if [[ -d "$CONTRACTS_DIR" ]] && [[ -n "$(ls -A "$CONTRACTS_DIR" 2>/dev/null)" ]]; then
    docs+=("contracts/")
fi

[[ -f "$QUICKSTART" ]] && docs+=("quickstart.md")

# Include tasks.md if requested and it exists
if $INCLUDE_TASKS && [[ -f "$TASKS" ]]; then
    docs+=("tasks.md")
fi

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if [[ ${#docs[@]} -eq 0 ]]; then
        json_docs="[]"
    else
        json_docs=$(printf '"%s",' "${docs[@]}")
        json_docs="[${json_docs%,}]"
    fi

    printf '{"TASK_ID":"%s","FEATURE_DIR":"%s","AVAILABLE_DOCS":%s}\n' "$TASK_ID" "$FEATURE_DIR" "$json_docs"
else
    # Text output
    echo "TASK_ID: $TASK_ID"
    echo "FEATURE_DIR: $FEATURE_DIR"
    echo "AVAILABLE_DOCS:"

    # Show status of each potential document
    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"

    if $INCLUDE_TASKS; then
        check_file "$TASKS" "tasks.md"
    fi
fi
