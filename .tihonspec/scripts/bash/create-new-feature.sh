#!/usr/bin/env bash

set -e

# Source environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-env.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common-env.sh" >&2
    exit 1
}
source "$SCRIPT_DIR/common.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common.sh" >&2
    exit 1
}

JSON_MODE=false
TICKET_ID=""
FEATURE_DESCRIPTION=""

# Parse arguments
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 <ticket-id> <feature_description> [--json]"
            echo ""
            echo "Arguments:"
            echo "  <ticket-id>         The ticket ID in format [folder/]prefix-### (e.g., aa-001, hotfix/aa-123)"
            echo "  <feature_description> Description of the feature"
            echo ""
            echo "Options:"
            echo "  --json             Output in JSON format"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Configuration:"
            echo "  Allowed prefixes: $TIHONSPEC_PREFIX_LIST"
            echo "  Default folder: $TIHONSPEC_DEFAULT_FOLDER"
            echo "  Main branch: $TIHONSPEC_MAIN_BRANCH"
            echo ""
            echo "Examples:"
            echo "  $0 aa-001 'Add user authentication system'"
            echo "  $0 hotfix/aa-123 'Critical bug fix' --json"
            exit 0
            ;;
        *)
            # First non-flag argument is ticket ID, rest is description
            if [ -z "$TICKET_ID" ]; then
                TICKET_ID="$arg"
            else
                if [ -n "$FEATURE_DESCRIPTION" ]; then
                    FEATURE_DESCRIPTION="$FEATURE_DESCRIPTION $arg"
                else
                    FEATURE_DESCRIPTION="$arg"
                fi
            fi
            ;;
    esac
    i=$((i + 1))
done

# Validate that both ticket ID and description are provided
if [ -z "$TICKET_ID" ]; then
    echo "ERROR: Missing required argument: <ticket-id>" >&2
    echo "Usage: $0 <ticket-id> <feature_description> [--json]" >&2
    echo "Example: $0 aa-001 'Add user authentication system'" >&2
    exit 1
fi

if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "ERROR: Missing required argument: <feature_description>" >&2
    echo "Usage: $0 <ticket-id> <feature_description> [--json]" >&2
    echo "Example: $0 aa-001 'Add user authentication system'" >&2
    exit 1
fi

# Case-insensitive: convert ticket ID to lowercase
TICKET_ID=$(echo "$TICKET_ID" | tr '[:upper:]' '[:lower:]')

# Parse and validate ticket ID using environment configuration
parsed=$(parse_ticket_id "$TICKET_ID") || exit 1
IFS='|' read -r folder prefix number <<< "$parsed"

# Full ticket ID for display (without folder if using default)
if [ "$folder" = "$TIHONSPEC_DEFAULT_FOLDER" ]; then
    DISPLAY_TICKET_ID="$prefix-$number"
else
    DISPLAY_TICKET_ID="$folder/$prefix-$number"
fi

# Get repository root using common-env function
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Check if git is available
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    HAS_GIT=true
else
    HAS_GIT=false
fi

# Set up paths using environment configuration
SPECS_DIR="$REPO_ROOT/$TIHONSPEC_SPECS_ROOT/$folder"
mkdir -p "$SPECS_DIR"

# Construct ticket identifier for this folder+prefix+number
TICKET_IDENTIFIER="$prefix-$number"

# Function to check if a ticket ID already exists
check_ticket_exists() {
    local folder="$1"
    local ticket_id="$2"

    # Check if branch already exists (local or remote)
    if [ "$HAS_GIT" = true ]; then
        # Fetch all remotes to get latest branch info (suppress errors if no remotes)
        git fetch --all --prune 2>/dev/null || true

        # Check remote branches
        if git ls-remote --heads origin 2>/dev/null | grep -q "refs/heads/${folder}/${ticket_id}\$"; then
            return 0  # Exists
        fi

        # Check local branches
        if git branch 2>/dev/null | grep -qE "^[* ]*${folder}/${ticket_id}\$"; then
            return 0  # Exists
        fi
    fi

    # Check specs directory
    if [ -d "$REPO_ROOT/$TIHONSPEC_SPECS_ROOT/$folder/$ticket_id" ]; then
        return 0  # Exists
    fi

    return 1  # Does not exist
}

# Check if ticket already exists
if check_ticket_exists "$folder" "$TICKET_IDENTIFIER"; then
    echo "ERROR: Ticket ID '$DISPLAY_TICKET_ID' already exists" >&2
    echo "Please use a different ticket ID or work on the existing feature" >&2
    exit 1
fi

# Run validation hook before creating feature
if ! run_validation_hook "$prefix" "$number" "$folder" "create"; then
    echo "ERROR: Validation failed for ticket '$DISPLAY_TICKET_ID'" >&2
    exit 1
fi

# Set branch and folder names
# Note: For simple parsing without validation, use parse_feature_id() from common-env.sh
BRANCH_NAME="$folder/$TICKET_IDENTIFIER"
FOLDER_NAME="$TICKET_IDENTIFIER"

# Branch creation removed - users must create manually before running this script
# Validate user is on correct branch (warning only, don't fail)
if [ "$HAS_GIT" = true ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ "$current_branch" != "$BRANCH_NAME" ]; then
        echo "⚠️  WARNING: Current branch ($current_branch) does not match expected ($BRANCH_NAME)" >&2
        echo "⚠️  Create branch manually: git checkout -b $BRANCH_NAME" >&2
        # Continue anyway - let user decide
    fi
fi


FEATURE_DIR="$SPECS_DIR/$FOLDER_NAME"
mkdir -p "$FEATURE_DIR"

TEMPLATE="$REPO_ROOT/$TIHONSPEC_SPECS_ROOT/templates/spec-template.md"
SPEC_FILE="$FEATURE_DIR/spec.md"
if [ -f "$TEMPLATE" ]; then cp "$TEMPLATE" "$SPEC_FILE"; else touch "$SPEC_FILE"; fi

# Set the SPECIFY_FEATURE environment variable for the current session
export SPECIFY_FEATURE="$FOLDER_NAME"

if $JSON_MODE; then
    printf '{"TASK_ID":"%s","BRANCH_NAME":"%s","SPEC_FILE":"%s","TICKET_ID":"%s","FOLDER":"%s","PREFIX":"%s","NUMBER":"%s","FEATURE_DESCRIPTION":"%s"}\n' \
        "$DISPLAY_TICKET_ID" "$BRANCH_NAME" "$SPEC_FILE" "$DISPLAY_TICKET_ID" "$folder" "$prefix" "$number" "$FEATURE_DESCRIPTION"
else
    echo "TASK_ID: $DISPLAY_TICKET_ID"
    echo "EXPECTED_BRANCH: $BRANCH_NAME"
    echo "CURRENT_BRANCH: $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'N/A')"
    echo "SPEC_FILE: $SPEC_FILE"
    echo "FOLDER: $folder"
    echo "PREFIX: $prefix"
    echo "NUMBER: $number"
    echo "FEATURE_DESCRIPTION: $FEATURE_DESCRIPTION"
fi
