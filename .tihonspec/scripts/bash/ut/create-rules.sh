#!/bin/bash
#
# create-rules.sh - Validate environment for /ut:create-rules command
#
# Usage: create-rules.sh
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

# Get repository root
REPO_ROOT=$(get_repo_root)

# Define output paths
RULES_DIR="$REPO_ROOT/docs/rules/test"
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
  "REPO_ROOT": "$(json_escape "$REPO_ROOT")",
  "RULES_DIR": "$(json_escape "$RULES_DIR")",
  "RULES_FILE": "$(json_escape "$RULES_FILE")",
  "TEMPLATE_FILE": "$(json_escape "$TEMPLATE_FILE")",
  "EXISTING_RULES": "$(json_escape "$EXISTING_RULES")",
  "MODE": "$MODE"
}
EOF
