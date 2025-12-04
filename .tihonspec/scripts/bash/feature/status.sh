#!/bin/bash
#
# feature-status.sh - Bash wrapper for /feature.status command
#
# Usage: feature-status.sh [feature-id]
# Example: feature-status.sh aa-2
#          feature-status.sh          (lists all feature)
#
# This script handles argument parsing and basic file checks.
# All intelligent analysis and reporting is handled by the AI agent.

set -e  # Exit on error

# Source environment configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common-env.sh" 2>/dev/null || {
    echo "ERROR: Failed to load common-env.sh" >&2
    exit 1
}

# Parse arguments
FEATURE_ID="$1"

# Set up paths using environment configuration
REPO_ROOT=$(get_repo_root)
feature_DIR="${REPO_ROOT}/${TIHONSPEC_SPECS_ROOT}/${TIHONSPEC_DEFAULT_FOLDER}"

# Check if feature directory exists
if [ ! -d "$feature_DIR" ]; then
    echo ""
    echo "❌ No .tihonspec/feature directory found"
    echo ""
    echo "This doesn't appear to be a TihonSpec-enabled project."
    echo ""
    echo "Initialize TihonSpec:"
    echo "  1. Create .tihonspec/feature directory"
    echo "  2. Run: /feature.tihonspec <feature-id>"
    exit 1
fi

# If no feature ID, list all feature
if [ -z "$FEATURE_ID" ]; then
    echo ""
    echo "📂 Available feature"
    echo "===================="
    echo ""

    FEATURE_COUNT=0

    for feature_dir in "$feature_DIR"/*; do
        if [ -d "$feature_dir" ]; then
            FEATURE_ID=$(basename "$feature_dir")
            FEATURE_COUNT=$((FEATURE_COUNT + 1))

            # Get last modified time
            LAST_MODIFIED=$(find "$feature_dir" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -rn | head -1 || echo "0")
            if [ "$LAST_MODIFIED" != "0" ]; then
                LAST_MODIFIED_DATE=$(date -d @$LAST_MODIFIED "+%Y-%m-%d %H:%M" 2>/dev/null || date -r $LAST_MODIFIED "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
            else
                LAST_MODIFIED_DATE="Never"
            fi

            # Quick status check
            STATUS="📋 Empty"
            if [ -f "$feature_dir/spec.md" ] || [ -f "$feature_dir/test-spec.md" ]; then
                if [ -f "$feature_dir/tasks.md" ]; then
                    # Check completion
                    TOTAL_TASKS=$(grep -c "^- \[" "$feature_dir/tasks.md" 2>/dev/null || echo "0")
                    COMPLETED_TASKS=$(grep -c "^- \[X\]" "$feature_dir/tasks.md" 2>/dev/null || echo "0")

                    if [ "$TOTAL_TASKS" -gt 0 ]; then
                        PERCENT=$((COMPLETED_TASKS * 100 / TOTAL_TASKS))
                        if [ "$PERCENT" -eq 100 ]; then
                            STATUS="✅ Complete"
                        elif [ "$PERCENT" -gt 0 ]; then
                            STATUS="⏳ In Progress ($PERCENT%)"
                        else
                            STATUS="📋 Planned"
                        fi
                    else
                        STATUS="📋 Planned"
                    fi
                else
                    STATUS="📝 Specified"
                fi
            fi

            # Get feature name from spec.md if available
            FEATURE_NAME="$FEATURE_ID"
            if [ -f "$feature_dir/spec.md" ]; then
                FEATURE_NAME=$(grep -m 1 "^# " "$feature_dir/spec.md" 2>/dev/null | sed 's/^# //' || echo "$FEATURE_ID")
            fi

            echo "$FEATURE_ID: $FEATURE_NAME"
            echo "  Status: $STATUS"
            echo "  Last modified: $LAST_MODIFIED_DATE"
            echo ""
        fi
    done

    if [ "$FEATURE_COUNT" -eq 0 ]; then
        echo "No feature found."
        echo ""
        echo "Create your first feature:"
        echo "  /feature.tihonspec <feature-id>"
    else
        echo "Use: /feature.status <feature-id> for details"
    fi

    echo ""
    exit 0
fi

# Case-insensitive: convert feature ID to lowercase
FEATURE_ID=$(echo "$FEATURE_ID" | tr '[:upper:]' '[:lower:]')

# Specific feature status - parse feature ID
if [[ "$FEATURE_ID" == */* ]]; then
    # Contains folder: hotfix/aa-2
    FOLDER="${FEATURE_ID%%/*}"
    TICKET="${FEATURE_ID#*/}"
else
    # No folder, use default: aa-2
    FOLDER="$TIHONSPEC_DEFAULT_FOLDER"
    TICKET="$FEATURE_ID"
fi

FEATURE_DIR="${REPO_ROOT}/${TIHONSPEC_SPECS_ROOT}/${FOLDER}/${TICKET}"

if [ ! -d "$FEATURE_DIR" ]; then
    echo ""
    echo "❌ Feature '$FEATURE_ID' not found"
    echo ""
    echo "Available feature:"

    for feature_dir in "$feature_DIR"/*; do
        if [ -d "$feature_dir" ]; then
            echo "  - $(basename "$feature_dir")"
        fi
    done

    echo ""
    echo "Create new feature:"
    echo "  /feature.tihonspec $FEATURE_ID"
    exit 1
fi

# Feature exists, gather basic info
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  TihonSpec Status: Feature $FEATURE_ID"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Check artifacts
SPEC_EXISTS=false
PLAN_EXISTS=false
TASKS_EXISTS=false
TEST_SPEC_EXISTS=false
COVERAGE_EXISTS=false
TEST_PLAN_EXISTS=false
REVIEW_EXISTS=false
RESULTS_EXISTS=false

if [ -f "$FEATURE_DIR/spec.md" ]; then
    SPEC_EXISTS=true
fi

if [ -f "$FEATURE_DIR/plan.md" ]; then
    PLAN_EXISTS=true
fi

if [ -f "$FEATURE_DIR/tasks.md" ]; then
    TASKS_EXISTS=true
fi

if [ -f "$FEATURE_DIR/test-spec.md" ]; then
    TEST_SPEC_EXISTS=true
fi

if [ -f "$FEATURE_DIR/coverage-report.json" ]; then
    COVERAGE_EXISTS=true
fi

if [ -f "$FEATURE_DIR/test-plan.md" ]; then
    TEST_PLAN_EXISTS=true
fi

if [ -f "$FEATURE_DIR/review-report.md" ]; then
    REVIEW_EXISTS=true
fi

if [ -f "$FEATURE_DIR/test-results.md" ]; then
    RESULTS_EXISTS=true
fi

# Count test files
TEST_FILE_COUNT=0
while IFS= read -r -d '' file; do
    TEST_FILE_COUNT=$((TEST_FILE_COUNT + 1))
done < <(find "$REPO_ROOT" -type f \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.jsx" -o -name "*.test.tsx" -o -name "*.spec.js" -o -name "*.spec.ts" -o -name "test_*.py" -o -name "*_test.py" \) -print0 2>/dev/null)

# Check git status
GIT_BRANCH="Unknown"
GIT_AVAILABLE=false
if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_AVAILABLE=true
    GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "Unknown")
fi

# Display summary
echo "Feature: $FEATURE_ID"
echo "Location: $FEATURE_DIR"
if [ "$GIT_AVAILABLE" == true ]; then
    echo "Branch: $GIT_BRANCH"
fi
echo ""

# Determine workflows
HAS_TIHONSPEC=false
HAS_UT=false

if [ "$SPEC_EXISTS" == true ] || [ "$PLAN_EXISTS" == true ] || [ "$TASKS_EXISTS" == true ]; then
    HAS_TIHONSPEC=true
fi

if [ "$TEST_SPEC_EXISTS" == true ] || [ "$COVERAGE_EXISTS" == true ] || [ "$TEST_PLAN_EXISTS" == true ] || [ "$TEST_FILE_COUNT" -gt 0 ]; then
    HAS_UT=true
fi

# Show basic workflow status
if [ "$HAS_TIHONSPEC" == false ] && [ "$HAS_UT" == false ]; then
    echo "⚠️  No workflow artifacts found"
    echo ""
    echo "This feature directory is empty."
    echo ""
    echo "Get started:"
    echo "  → /feature.tihonspec $FEATURE_ID  (Create specification)"
    echo "  → /ut.tihonspec $FEATURE_ID       (Create test specification)"
    echo ""
    exit 0
fi

# Display artifact list
echo "Detected Workflows:"
if [ "$HAS_TIHONSPEC" == true ]; then
    echo "  ✅ TihonSpec Default Workflow"
fi
if [ "$HAS_UT" == true ]; then
    echo "  ✅ UT Workflow"
fi
echo ""

# Show file list
echo "Artifacts:"
if [ "$SPEC_EXISTS" == true ]; then
    SPEC_TIME=$(stat -c %y "$FEATURE_DIR/spec.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/spec.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ spec.md ($SPEC_TIME)"
fi

if [ "$PLAN_EXISTS" == true ]; then
    PLAN_TIME=$(stat -c %y "$FEATURE_DIR/plan.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/plan.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ plan.md ($PLAN_TIME)"
fi

if [ "$TASKS_EXISTS" == true ]; then
    TASKS_TIME=$(stat -c %y "$FEATURE_DIR/tasks.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/tasks.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ tasks.md ($TASKS_TIME)"
fi

if [ "$TEST_SPEC_EXISTS" == true ]; then
    TEST_SPEC_TIME=$(stat -c %y "$FEATURE_DIR/test-spec.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/test-spec.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ test-spec.md ($TEST_SPEC_TIME)"
fi

if [ "$COVERAGE_EXISTS" == true ]; then
    COVERAGE_TIME=$(stat -c %y "$FEATURE_DIR/coverage-report.json" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/coverage-report.json" 2>/dev/null || echo "Unknown")
    echo "  ✅ coverage-report.json ($COVERAGE_TIME)"
fi

if [ "$TEST_PLAN_EXISTS" == true ]; then
    TEST_PLAN_TIME=$(stat -c %y "$FEATURE_DIR/test-plan.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/test-plan.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ test-plan.md ($TEST_PLAN_TIME)"
fi

if [ "$TEST_FILE_COUNT" -gt 0 ]; then
    echo "  ✅ Generated tests ($TEST_FILE_COUNT files)"
fi

if [ "$REVIEW_EXISTS" == true ]; then
    REVIEW_TIME=$(stat -c %y "$FEATURE_DIR/review-report.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/review-report.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ review-report.md ($REVIEW_TIME)"
fi

if [ "$RESULTS_EXISTS" == true ]; then
    RESULTS_TIME=$(stat -c %y "$FEATURE_DIR/test-results.md" 2>/dev/null | cut -d' ' -f1 || stat -f "%Sm" -t "%Y-%m-%d" "$FEATURE_DIR/test-results.md" 2>/dev/null || echo "Unknown")
    echo "  ✅ test-results.md ($RESULTS_TIME)"
fi

echo ""

# ============================================================
# AI AGENT HANDOFF
# ============================================================
# This bash script handles basic file detection and validation.
# The AI agent (via /feature.status command prompt) will now:
# - Perform intelligent analysis of workflow state
# - Calculate progress and metrics
# - Generate smart next-step recommendations with reasoning
# - Display enhanced status report with contextual tips
# ============================================================

# The AI agent will now provide detailed analysis
echo \"🤖 AI agent will provide intelligent status analysis...\"
echo "   (The /feature.status command prompt handles intelligent analysis)"
echo ""
echo "✅ Ready for AI agent processing"
echo ""
echo "Next steps for AI agent:"
echo "1. Analyze TihonSpec workflow progress (if applicable)"
echo "   - Parse tasks.md for completion status"
echo "   - Calculate progress percentage"
echo "   - Identify current phase"
echo ""
echo "2. Analyze UT workflow progress (if applicable)"
echo "   - Check each pipeline step status"
echo "   - Count test scenarios, cases, files"
echo "   - Extract quality scores from review"
echo "   - Extract test results from execution"
echo ""
echo "3. Determine current workflow state"
echo "   - What's been completed"
echo "   - What's in progress"
echo "   - What's pending"
echo ""
echo "4. Generate next action recommendations"
echo "   - Specific commands to run next"
echo "   - Priority-ordered suggestions"
echo "   - Alternative paths available"
echo ""
echo "5. Display comprehensive status report with:"
echo "   - Visual progress bars"
echo "   - Detailed artifact information"
echo "   - Git status (if available)"
echo "   - Actionable next steps"
echo ""

# Note: In actual execution, Claude Code will invoke the slash command
# which reads this script's output and continues with detailed analysis

exit 0
