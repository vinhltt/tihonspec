# /feature.status - Track Workflow Progress

## ⛔ CRITICAL: Error Handling

**If ANY script returns an error, you MUST:**
1. **STOP immediately** - Do NOT attempt workarounds or auto-fixes
2. **Report the error** - Show the exact error message to the user
3. **Wait for user** - Ask user how to proceed before taking any action

**DO NOT:**
- Try alternative approaches when scripts fail
- Create branches manually when script validation fails
- Guess or assume what the user wants after an error
- Continue with partial results

---

## Purpose

Display comprehensive status for any TihonSpec feature workflow, including:
- **TihonSpec Default Workflow**: spec.md → plan.md → tasks.md → implementation
- **UT Workflow**: test-spec.md → coverage-report.json → test-plan.md → generated tests → review → execution
- **Mixed State**: feature using both workflows

Helps developers understand what's been completed, what's in progress, and what to do next.

## Input

- **Feature ID**: Required argument (e.g., `{prefix}-2` where prefix is from TIHONSPEC_PREFIX_LIST)
- **Workflow Detection**: Auto-detects which workflows are active based on artifacts

## Output

Displays to terminal:
1. **Feature Overview**: ID, description, branch status
2. **Workflow Detection**: Which workflows are active
3. **Artifact Status**: What files exist and when they were last modified
4. **Progress Summary**: Completion percentage and visual progress bar
5. **Current State**: What's been done
6. **Next Actions**: Specific commands to continue workflow
7. **Recommendations**: Suggested next steps based on state

## Execution Instructions
### Step 0: Validate or Infer Task ID

**CRITICAL**: Handle task_id before any operations.

1. **Parse user input**:
   - Extract first argument from `$ARGUMENTS`
   - Expected format: `[folder/]prefix-number`

2. **Check if task_id provided**:

   **If task_id provided and valid** (matches pattern `[folder/]prefix-number`):
   - Convert to lowercase (case-insensitive)
   - → Proceed to Step 1 with this task_id

   **If task_id missing or invalid**:
   - → Proceed to inference (step 3)

3. **Infer from conversation context**:
   - Search this conversation for:
     - Previous `/feature.*` or `/ut.*` command executions with task_id
     - Task_id patterns mentioned (e.g., "pref-001", "MRR-123", "aa-2")
     - Output mentioning "Feature pref-001" or similar

   **If context found** (e.g., "pref-001"):
   - Use **AskUserQuestion** tool to confirm:
     ```json
     {
       "questions": [{
         "question": "No task_id provided. Use detected context 'pref-001'?",
         "header": "Task ID",
         "options": [
           {"label": "Yes, use pref-001", "description": "Proceed with the detected task"},
           {"label": "No, specify another", "description": "I'll provide a different task_id"}
         ],
         "multiSelect": false
       }]
     }
     ```
   - If user selects "Yes" → task_id = inferred value (lowercase), proceed to Step 1
   - If user selects "No" → Show usage, STOP

   **If NO context found**:
   ```
   ❌ Error: task_id is required

   Usage: /feature.status <task-id>
   Example: /feature.status pref-001

   No previous task context found in this conversation.
   ```
   STOP - Do NOT proceed to Step 1

4. **Validate task_id format**:
   - Must match pattern: `[folder/]prefix-number`
   - Prefix must be in `.feature.env` TIHONSPEC_PREFIX_LIST
   - Examples:
     - ✅ `/feature.status pref-001` → task_id: `pref-001`
     - ✅ `/feature.status PREF-001` → task_id: `pref-001` (case-insensitive)
     - ✅ `/feature.status hotfix/pref-123` → task_id: `hotfix/pref-123`
     - ❌ `/feature.status` without context → ERROR (no task ID)

5. **Determine feature directory**:
   - Pattern: `.tihonspec/{folder}/{prefix-number}/`
   - Default folder: `feature` (from TIHONSPEC_DEFAULT_FOLDER)
   - If not found → ERROR, suggest running `/feature.tihonspec` first

**After Validation**:
- Proceed to Step 1 only if task_id valid
- Use task_id to locate feature files

### Step 0.5: Load Project Context (Optional)

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output into PROJECT_CONTEXT
3. **If PROJECT_CONTEXT.CONFIG_FOUND is true**:
   - Store PROJECT_NAME, PROJECT_PATH, METADATA for context
   - Read each file in RULES_FILES array
   - Apply INLINE_RULES to generation guidelines
   - Use METADATA (language, framework) for tech-specific guidance
4. **If PROJECT_CONTEXT.CONFIG_FOUND is false**: Continue with defaults (backward compatible)
5. **If rules file not found**: Warning "Rule file not found: {path}", continue

**Project Context** (use in later steps):
- Project: {PROJECT_NAME}
- Language: {METADATA.language}
- Framework: {METADATA.framework}
- Rules: Applied from RULES_FILES and INLINE_RULES

### Step 1: Validate Feature Directory

```bash
# Check if feature directory exists
FEATURE_DIR=".tihonspec/feature/{feature-id}"

if not exists:
  Report: "Feature {feature-id} not found. Run: /feature.tihonspec {feature-id}"
  Exit
```

### Step 2: Detect Active Workflows

Check for workflow artifacts:

**TihonSpec Default Workflow Artifacts**:
- `spec.md` - Feature specification
- `plan.md` - Implementation plan
- `tasks.md` - Task breakdown
- Implementation files (various locations)

**UT Workflow Artifacts**:
- `test-spec.md` - Test specification
- `coverage-report.json` - Coverage analysis
- `test-plan.md` - Test implementation plan
- Generated test files (*.test.*, test_*.py)
- `review-report.md` - Test quality review
- `test-results.md` - Test execution results

**Workflow States**:
1. **None**: No artifacts exist yet
2. **TihonSpec Only**: Has spec.md/plan.md/tasks.md
3. **UT Only**: Has test-spec.md/coverage-report.json/test-plan.md
4. **Both**: Has artifacts from both workflows
5. **Implementation**: Has code changes in git

### Step 3: Analyze TihonSpec Default Workflow

If spec.md, plan.md, or tasks.md exists:

**Check Completeness**:

```markdown
## TihonSpec Default Workflow

### Artifacts
- ✅ spec.md (Modified: 2 days ago)
- ✅ plan.md (Modified: 2 days ago)
- ✅ tasks.md (Modified: 1 hour ago)

### Progress
Tasks: 27/49 completed (55%)
[████████████░░░░░░░░░░] 55%

### Status
- Phase 1-6: ✅ Complete
- Phase 7: ⏳ In Progress (T028-T031)
- Phase 8-10: ⏸️ Pending
```

**Parse tasks.md**:
- Count total tasks: `grep -c "^- \[" tasks.md`
- Count completed: `grep -c "^- \[X\]" tasks.md`
- Find current phase: Last incomplete task
- Extract checkpoint status

### Step 4: Analyze UT Workflow

If test-spec.md, coverage-report.json, or test-plan.md exists:

**Check UT Pipeline**:

```markdown
## UT Workflow

### Pipeline Status

1. ✅ Test Specification (/ut.tihonspec)
   - File: test-spec.md
   - Modified: 1 day ago
   - Scenarios: 6 | Test Cases: 18

2. ✅ Code Analysis (/ut.analyze)
   - File: coverage-report.json
   - Modified: 1 day ago
   - Framework: Jest 29.7.0
   - Files Analyzed: 12

3. ✅ Implementation Plan (/ut.plan)
   - File: test-plan.md
   - Modified: 1 day ago
   - Test Suites: 3 | Mocking Strategy: External APIs

4. ✅ Test Generation (/ut.generate)
   - Test Files: 3 generated
   - Total Tests: 19
   - Last Modified: 1 hour ago

5. ⏸️ Test Review (/ut.review)
   - Status: Not started
   - Next: Run /ut.review pref-2

6. ⏸️ Test Execution (/ut.run)
   - Status: Not started
   - Next: Run /ut.run pref-2

### Progress
Pipeline: 4/6 steps completed (67%)
[████████████████░░░░░░] 67%
```

**Analyze Each Step**:

**Step 1: /ut.tihonspec**
- Check: test-spec.md exists
- Extract: Scenario count (`grep -c "^### TS-"`)
- Extract: Test case count (`grep -c "^##### TC-"`)

**Step 2: /ut.analyze**
- Check: coverage-report.json exists
- Extract: Framework info (jq '.environment.framework')
- Extract: File count (jq '.analysis.filesAnalyzed')

**Step 3: /ut.plan**
- Check: test-plan.md exists
- Extract: Test suite count
- Extract: Mocking strategy summary

**Step 4: /ut.generate**
- Search for test files (*.test.*, test_*.py)
- Count test files
- Count test cases (grep "it(" or "def test_")

**Step 5: /ut.review**
- Check: review-report.md exists
- Extract: Quality score if exists

**Step 6: /ut.run**
- Check: test-results.md exists
- Extract: Pass/fail summary if exists

### Step 5: Check Git Status

**Branch Information**:
```bash
# Check current branch
git branch --show-current

# Check if feature branch exists
git branch --list "feature/{feature-id}" "feature/{feature-id}"

# Check uncommitted changes
git status --porcelain .tihonspec/feature/{feature-id}
```

**Display**:
```markdown
## Git Status

Branch: feature/pref-2 ✅
Uncommitted Changes: 3 files
- .tihonspec/feature/pref-2/test-spec.md (modified)
- .tihonspec/feature/pref-2/test-plan.md (modified)
- tests/calculator.test.ts (new file)
```

### Step 6: Determine Current State

Based on artifacts, determine workflow state:

**State Matrix**:

| Artifacts Present | State | Description |
|-------------------|-------|-------------|
| None | Not Started | Feature directory empty |
| spec.md only | Specified | Feature spec created |
| spec.md + plan.md | Planned | Implementation plan ready |
| spec.md + plan.md + tasks.md | Ready to Implement | Tasks defined |
| tasks.md with completed items | In Progress | Implementation ongoing |
| test-spec.md only | Test Specified | Tests planned |
| test-spec.md + coverage-report.json | Analyzed | Code gaps identified |
| +test-plan.md | Test Planned | Test structure defined |
| +generated tests | Tests Generated | Test code created |
| +review-report.md | Reviewed | Quality checked |
| +test-results.md | Executed | Tests run |

### Step 7: Determine Intelligent Next Step Recommendation

Based on current state, analyze workflow context and recommend the most logical next step with reasoning.

**Recommendation Logic**:

1. **Analyze Current State**: Identify which artifacts exist and their timestamps
2. **Detect Workflow Type**: TihonSpec only, UT only, or both
3. **Check Prerequisites**: Validate if next step has all required inputs
4. **Consider Alternatives**: Identify valid alternative paths
5. **Provide Context**: Explain WHY this step and WHAT it does

**State-Based Recommendations**:

**State: None (No artifacts)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /feature.tihonspec {feature-id}

Why this step:
  • No artifacts exist yet - start with feature specification
  • Specification is the foundation for all other workflows
  • Defines requirements, user stories, and success criteria

What it will do:
  • Create spec.md with structured requirements
  • Generate quality validation checklist
  • Ask up to 3 clarification questions if needed
  • Establish clear scope for development

After this:
  → /feature.plan {feature-id} (create implementation plan)
  → /ut.tihonspec {feature-id} (TDD: write tests first)

Alternative Path (TDD Approach):
  → /ut.tihonspec {feature-id}
  Note: Requires spec.md - will prompt to create it first
```

**State: Specified (spec.md exists, no plan.md)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /feature.plan {feature-id}

Why this step:
  • Specification is complete (spec.md exists)
  • Next logical step is creating implementation plan
  • Plan translates requirements into technical architecture

What it will do:
  • Analyze spec.md functional requirements
  • Generate technical design and architecture
  • Create plan.md with implementation strategy
  • Identify technical dependencies and risks

After this:
  → /feature.tasks {feature-id} (break down into tasks)

Alternative Path (TDD Approach):
  → /ut.tihonspec {feature-id}
  Why: Write tests before implementation
  • Ensures testability from the start
  • Clarifies requirements through test scenarios
  • Enables test-driven development workflow
```

**State: Planned (plan.md exists, no tasks.md)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /feature.tasks {feature-id}

Why this step:
  • Implementation plan ready (plan.md exists)
  • Need task breakdown before coding
  • Tasks provide clear, actionable steps

What it will do:
  • Generate tasks.md from plan.md
  • Break down into small, testable increments
  • Organize by phases with dependencies
  • Create checkpoints for validation

After this:
  → /feature.implement {feature-id} (start coding)
  → /ut.tihonspec {feature-id} (write tests first)

Alternative Path (Start Testing):
  → /ut.tihonspec {feature-id}
  Why: Begin test specification while plan is fresh
  • Parallel workflow - tests and implementation together
  • Ensures comprehensive test coverage planning
```

**State: Ready to Implement (tasks.md exists, no implementation)**
```markdown
💡 RECOMMENDED NEXT STEP

You have 2 recommended approaches:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Option A: Traditional Approach (Code First)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  → /feature.implement {feature-id}

  Why:
    • Tasks defined and ready
    • Fastest path to working implementation
    • Test after confirming functionality

  Workflow:
    1. /feature.implement → code implementation
    2. /ut.tihonspec → define tests
    3. /ut.analyze → identify gaps
    4. /ut.generate → create tests

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Option B: TDD Approach (Tests First) ⭐ Recommended
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  → /ut.tihonspec {feature-id}

  Why:
    • Define expected behavior before coding
    • Ensures comprehensive test coverage
    • Catches design issues early
    • Enables true test-driven development

  Workflow:
    1. /ut.tihonspec → define test requirements
    2. /ut.analyze → check current code state
    3. /ut.plan → plan test structure
    4. /ut.generate → create test files
    5. /feature.implement → implement to pass tests

Which approach fits your workflow better?
```

**State: Implementation in Progress (tasks.md has completed items)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /feature.implement {feature-id}

Why this step:
  • Implementation already started ({X}% complete)
  • Continue momentum on current phase
  • {Y} tasks remaining in current phase

Current Focus:
  Phase {N}: {Phase Name}
  Progress: {completed}/{total} tasks
  Next task: {next-task-description}

What to do:
  • Continue implementing remaining tasks
  • Commit after each task completion
  • Run tests if available
  • Update tasks.md with [X] when done

After completing current phase:
  → Continue to next phase
  → /ut.tihonspec {feature-id} (add tests if not done)

Parallel Option:
  → /ut.tihonspec {feature-id}
  Why: Add tests while implementation is ongoing
  • Ensures testability of current code
  • Catches issues early
  • Enables continuous testing
```

**State: Test Specification Created (test-spec.md exists, no coverage-report)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /ut.analyze {feature-id}

Why this step:
  • Test specification complete (test-spec.md exists)
  • Next step is analyzing existing codebase
  • Identifies what needs testing and coverage gaps

What it will do:
  • Scan codebase for testable code
  • Detect testing framework in use
  • Generate coverage-report.json with gaps
  • Map code to test scenarios from test-spec.md

After this:
  → /ut.plan {feature-id} (create test implementation plan)

Prerequisites Check:
  ⚠️  Ensure spec.md exists and code is available
  If no code yet: Consider implementing first or continue with /ut.plan

Alternative Path:
  → /ut.plan {feature-id}
  Why: Skip analysis if no code exists yet
  • Useful for TDD approach
  • Plan tests before implementation
```

**State: Code Analyzed (coverage-report.json exists, no test-plan.md)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /ut.plan {feature-id}

Why this step:
  • Code analysis complete (coverage-report.json exists)
  • Framework detected: {framework-name}
  • {X} files need testing
  • Next step is creating test implementation plan

What it will do:
  • Read test-spec.md and coverage-report.json
  • Plan test file structure
  • Define mocking strategy for dependencies
  • Generate test-plan.md document

After this:
  → /ut.generate {feature-id} (generate test code)

Coverage Analysis:
  • Files analyzed: {count}
  • Coverage gaps: {gap-count} areas
  • Priority: {high/medium/low}
```

**State: Test Plan Ready (test-plan.md exists, no test files)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /ut.generate {feature-id}

Why this step:
  • Test plan complete (test-plan.md exists)
  • Ready to generate actual test code
  • Will create executable test files

What it will do:
  • Read test-plan.md structure
  • Generate test files using framework templates
  • Create {X} test suites with {Y} test cases
  • Set up mocks and fixtures as planned

After this:
  → /ut.review {feature-id} (review test quality)
  → /ut.run {feature-id} (execute tests)

Prerequisites:
  ✅ Test framework: {framework}
  ✅ Test plan: {suite-count} suites planned
  ✅ Mocking strategy: Defined
```

**State: Tests Generated (test files exist, no review)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /ut.review {feature-id}

Why this step:
  • Tests generated ({X} files, {Y} test cases)
  • Review ensures quality before execution
  • Catches common issues early

What it will do:
  • Analyze generated tests against test-spec.md
  • Check for missing scenarios or edge cases
  • Validate mocking strategy implementation
  • Score quality and suggest improvements
  • Generate review-report.md

After this:
  → Address any quality issues identified
  → /ut.run {feature-id} (execute tests)

Alternative Path (Skip Review):
  → /ut.run {feature-id}
  ⚠️  Not recommended: May miss quality issues
  • Review helps catch problems before running
  • Saves debugging time later
  • Ensures comprehensive coverage

Generated Tests:
  • Test files: {count}
  • Test cases: {count}
  • Framework: {framework}
  • Last modified: {timestamp}
```

**State: Reviewed (review-report.md exists, no test-results.md)**
```markdown
💡 RECOMMENDED NEXT STEP

Primary Recommendation:
  → /ut.run {feature-id}

Why this step:
  • Tests reviewed (review-report.md exists)
  • Quality score: {score}/100
  • Ready to execute tests and verify functionality

What it will do:
  • Execute all generated tests
  • Parse test results and failures
  • Generate test-results.md report
  • Suggest fixes for failing tests

Review Results:
  • Quality Score: {score}/100
  • Issues Found: {count}
  • Status: {Pass/NeedsWork}

Action Based on Review:
  {if score < 70}
  ⚠️  Consider fixing quality issues first
  • Review report shows {X} significant issues
  • Fixing now saves debugging time later
  {else}
  ✅ Quality looks good - proceed with execution
  {endif}

After this:
  → Fix any failing tests
  → Re-run until all tests pass
  → /feature.implement {feature-id} (continue implementation)
```

**State: Tests Executed (test-results.md exists)**
```markdown
💡 RECOMMENDED NEXT STEP

{if tests passing}
Primary Recommendation:
  → /feature.implement {feature-id}

Why this step:
  • All tests passing ✅ ({X}/{X} tests)
  • Test coverage: {Y}%
  • Safe to continue implementation

What to do next:
  • Continue implementing remaining feature
  • Keep tests passing as you add code
  • Run tests after each significant change

Test Results:
  ✅ Passed: {passed-count}
  ❌ Failed: 0
  Coverage: {coverage}%

{else}
Primary Recommendation:
  → Fix failing tests first

Why this step:
  • {X} tests failing (see test-results.md)
  • Need to resolve before continuing
  • Failing tests indicate issues in code or tests

Failure Analysis:
  ❌ Failed: {failed-count}/{total}
  📝 Details: .tihonspec/feature/{feature-id}/test-results.md

Common failure types:
  • Missing mocks: Check mock configuration
  • Incorrect assertions: Review expected vs actual
  • Setup issues: Verify test fixtures

After fixing:
  → /ut.run {feature-id} (re-run tests)
  → /feature.implement {feature-id} (when all pass)
{endif}

Parallel Option:
  → /ut.review {feature-id}
  Why: Re-review if you modified tests significantly
```

**State: Both Workflows Active**
```markdown
💡 RECOMMENDED NEXT STEP

Workflow Status:
  📋 TihonSpec: {tihonspec-phase} ({tihonspec-percent}% complete)
  🧪 UT Workflow: {ut-phase} ({ut-percent}% complete)

{determine which workflow is behind and recommend that}

Primary Recommendation:
  → {command for lagging workflow}

Why this step:
  • {workflow-name} is at {phase}
  • {other-workflow-name} is further ahead at {other-phase}
  • Balancing both workflows ensures quality

Suggested Approach:
  1. {next-command-workflow-1}
  2. {next-command-workflow-2}
  3. Alternate between workflows as needed

Alternative: Focus on one workflow
  • Complete TihonSpec first, then comprehensive testing
  • Complete UT first for TDD approach
```

### Step 8: Calculate Workflow Intelligence Metrics

Before displaying, calculate additional metrics for intelligent recommendations:

**Metrics to Calculate**:

1. **Workflow Balance Score**:
   ```
   tihonspec_progress = (completed_phases / total_phases) * 100
   ut_progress = (completed_steps / 6) * 100
   balance_score = abs(tihonspec_progress - ut_progress)
   
   If balance_score > 30: Recommend catching up lagging workflow
   ```

2. **Staleness Detection**:
   ```
   For each artifact, check days_since_modification
   If > 7 days: Flag as "May need refresh"
   If > 14 days: Warn "Consider updating"
   ```

3. **Blocking Issues**:
   ```
   Check for:
   - Missing prerequisites (e.g., test-spec needs spec.md)
   - Failed validations (checklist < 80% complete)
   - Test failures (from test-results.md)
   ```

4. **Next Step Confidence**:
   ```
   High confidence: All prerequisites exist, clear next step
   Medium confidence: Prerequisites exist, multiple valid paths
   Low confidence: Missing prerequisites, need user input
   ```

### Step 9: Display Enhanced Status Report

**Format with Intelligent Recommendations**:

```
╔══════════════════════════════════════════════════════╗
║  TihonSpec Status: Feature pref-2                        ║
╚══════════════════════════════════════════════════════╝

Feature: Unit Test Generation Command Flow
Location: .tihonspec/feature/pref-2
Branch: feature/pref-2 ✅

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 TihonSpec Default Workflow
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Artifacts:
  ✅ spec.md          (2 days ago)
  ✅ plan.md          (2 days ago)
  ✅ tasks.md         (1 hour ago)

Progress:
  Tasks: 31/49 completed (63%)
  [███████████████░░░░░░░░] 63%

Current Phase:
  Phase 8: User Story 6 - /ut.run
  Status: ✅ Complete (T032-T036)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 UT Workflow
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Pipeline Status:
  1. ✅ Test Specification      test-spec.md (1 day ago)
     Scenarios: 6 | Cases: 18

  2. ✅ Code Analysis           coverage-report.json (1 day ago)
     Framework: Jest 29.7.0 | Files: 12

  3. ✅ Implementation Plan     test-plan.md (1 day ago)
     Suites: 3 | Mocking: External APIs

  4. ✅ Test Generation         3 test files (1 hour ago)
     Total Tests: 19

  5. ⏸️ Test Review            Not started
     → Run: /ut.review pref-2

  6. ⏸️ Test Execution         Not started
     → Run: /ut.run pref-2

Progress:
  Pipeline: 4/6 steps completed (67%)
  [████████████████░░░░░░] 67%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Overall Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

State: Tests Generated, Ready for Review
Overall Progress: 65% complete

Git Status:
  Branch: feature/pref-2 ✅
  Uncommitted: 3 files modified

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 RECOMMENDED NEXT STEP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Primary Recommendation:
  → /ut.review pref-2

Why this step:
  • Tests have been generated (19 tests across 3 files)
  • Review ensures quality before execution
  • Catches common issues early (missing mocks, wrong assertions)
  • Quality gate before running tests

What it will do:
  • Analyze generated tests against test-spec.md
  • Check for missing scenarios or edge cases
  • Validate mocking strategy implementation
  • Score quality on weighted criteria (0-100)
  • Generate review-report.md with findings and suggestions

After this step:
  → Address any quality issues identified in review
  → /ut.run pref-2 (execute tests and verify functionality)

Generated Tests Summary:
  • Test files: 3
  • Test cases: 19
  • Framework: Jest 29.7.0
  • Last modified: 1 hour ago

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔀 ALTERNATIVE PATHS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Option A: Skip review and run tests directly
  → /ut.run pref-2
  ⚠️  Not recommended: May miss quality issues
  When to use: Quick validation, already confident in test quality

Option B: Continue TihonSpec implementation
  → /feature.implement pref-2
  When to use: Want to implement more feature before testing
  Note: 18 tasks remaining (37% incomplete)

Option C: Refine test specification
  → /ut.tihonspec pref-2
  When to use: Need to add more test scenarios
  Note: Will update existing test-spec.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 Tips
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

- Run /feature.status pref-2 anytime to check progress
- Both workflows can run independently or together
- TDD approach: Complete UT workflow before implementation
- Traditional approach: Implement first, then generate tests
```

### Step 10: Add Contextual Warnings and Tips

Based on detected state, add relevant warnings or tips:

**Staleness Warning**:
```
⚠️  ATTENTION: Some artifacts are outdated

  • spec.md: Modified 14 days ago
    Consider: Review and update if requirements changed
    → /feature.tihonspec pref-2

  • test-spec.md: Modified 10 days ago  
    If spec.md was updated, regenerate tests
    → /ut.tihonspec pref-2
```

**Missing Prerequisites**:
```
⚠️  PREREQUISITES MISSING

  Cannot run /ut.analyze without:
    ❌ spec.md (required)
    ❌ Source code files (required)

  Action required:
    1. Create specification: /feature.tihonspec pref-2
    2. Implement code: /feature.implement pref-2
    3. Then run: /ut.analyze pref-2
```

**Workflow Imbalance**:
```
💡 TIP: Workflow Imbalance Detected

  TihonSpec Progress: 85% (Implementation nearly done)
  UT Progress: 15% (Only test-spec created)

  Recommendation: Catch up on testing
    → /ut.analyze pref-2
    → /ut.plan pref-2
    → /ut.generate pref-2

  Why: Ensures code is testable before completion
```

**Test Failures**:
```
⚠️  TEST FAILURES DETECTED

  Recent test run: 14 passed, 5 failed
  Failure rate: 26%

  Priority Action:
    → Review test-results.md for failure details
    → Fix failing tests before continuing
    → Re-run: /ut.run pref-2

  Common fixes:
    • Update mocks if API changed
    • Fix assertions if logic changed
    • Check test data fixtures
```

### Step 11: Handle Edge Cases

**Feature not found**:
```
❌ Feature 'pref-2' not found

Available feature:
  - aa-1 (Awesome Agent Workflow)
  - aa-3 (Code Review Assistant)

Create new feature:
  → /feature.tihonspec pref-2
```

**Empty feature directory**:
```
⚠️  Feature 'pref-2' exists but has no artifacts

Get started:
  → /feature.tihonspec pref-2  (Create specification)
  → /ut.tihonspec pref-2       (Create test specification)
```

**Corrupted artifact** (invalid JSON, malformed markdown):
```
⚠️  Warning: coverage-report.json appears corrupted
    Unable to parse framework information

Regenerate:
  → /ut.analyze pref-2
```

### Step 12: Support Multiple feature

If no feature ID provided, list all feature:

```bash
/feature.status

# Output:
Available feature:
====================

aa-1: Awesome Agent Workflow
  Status: ✅ Complete
  Progress: 100%
  Last modified: 1 week ago

pref-2: Unit Test Generation Command Flow
  Status: ⏳ In Progress
  Progress: 65%
  Last modified: 1 hour ago

aa-3: Code Review Assistant
  Status: 📋 Planned
  Progress: 30%
  Last modified: 3 days ago

Use: /feature.status <feature-id> for details
```

## Quality Checklist

**Status Detection**:
- [ ] Feature directory validated
- [ ] Both workflows (TihonSpec + UT) detected correctly
- [ ] Artifact timestamps extracted and displayed
- [ ] Progress percentages calculated accurately
- [ ] Current state accurately determined
- [ ] Staleness detected (artifacts > 7 days old)
- [ ] Missing prerequisites identified

**Intelligent Recommendations**:
- [ ] Primary next step identified with high confidence
- [ ] Reasoning provided (Why this step?)
- [ ] Action description provided (What it will do?)
- [ ] Expected outcome described (After this?)
- [ ] Alternative paths listed when applicable
- [ ] Warnings shown for risky alternatives
- [ ] Prerequisites validated before recommending

**Contextual Intelligence**:
- [ ] Workflow balance score calculated
- [ ] Imbalance warnings shown if > 30% difference
- [ ] Test failures detected and highlighted
- [ ] Blocking issues identified
- [ ] Tips provided based on state

**Display Quality**:
- [ ] Visual progress bars displayed
- [ ] Git status checked and reported
- [ ] Edge cases handled gracefully
- [ ] Multi-feature listing supported
- [ ] Output is readable and well-formatted
- [ ] Emoji/icons used consistently

## Example Usage

```bash
# Check status of feature pref-2
/feature.status pref-2

# List all feature
/feature.status
```

## Error Handling

- **Feature not found**: List available feature, suggest creation
- **No artifacts**: Suggest starting commands
- **Corrupted files**: Warn and suggest regeneration
- **Git errors**: Display status without git info, continue

## Notes

- This is a **read-only command** - never modifies any files
- Supports **both workflows** - TihonSpec default and UT
- Provides **resumption guidance** after interruption
- Shows **realistic progress** based on actual artifacts
- **Actionable recommendations** - specific commands to run next
- **Visual progress indicators** - bars and percentages
- Works **without git** - degrades gracefully
- **Fast execution** - just file system checks, no heavy processing
