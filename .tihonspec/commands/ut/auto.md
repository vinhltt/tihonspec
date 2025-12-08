# /ut:auto - Automated Unit Test Workflow

## Purpose

Run the complete UT workflow automatically: plan -> generate -> run tests. Single command for end-to-end test creation.

---

## ⚠️ CRITICAL: Workflow Rules

**AUTO-CREATE BEHAVIOR** (for UT-only tasks):
- Feature directory not found → **Auto-created** by script
- spec.md not found → **Optional** - continue without it (use user prompt for context)

**MANDATORY STOP CONDITIONS** - When any of these errors occur, you MUST:
1. **STOP immediately** - Do NOT proceed to next step
2. **Report the error** to user with the suggested fix

| Error | Required Action |
|-------|-----------------|
| Script returns non-zero exit | STOP → Report error message to user |
| JSON parse fails | STOP → Report script output to user |
| Sub-workspace not found | STOP → Show available sub-workspaces |

**MANDATORY SEQUENCE** - Do NOT skip steps:
1. Run script → Get JSON output
2. If no spec.md and no ut-plan.md → **Create ut-plan.md first** based on user prompt
3. Then proceed to generate tests

---

## Usage

```bash
/ut:auto {feature-id}                         # Full workflow
/ut:auto {feature-id} --sub-workspace {name}  # Target specific sub-workspace
/ut:auto {feature-id} --skip-run              # Skip running tests
/ut:auto {feature-id} --plan-only             # Only create plan
/ut:auto {feature-id} --force                 # Overwrite existing
```

---

## Workflow

```
ut:auto
   |
   v
[Check UT Rules] --> [Create if missing] (uses --sub-workspace for path)
   |
   v
[Plan] --> ut-plan.md, ut-phase-*.md
   |
   v
[Generate] --> *.test.ts, *.spec.ts, etc.
   |
   v
[Run Tests] --> Report results
```

---

## Output

Creates all artifacts:
- `ut-plan.md` - Main test plan
- `ut-phase-01-setup.md` - Setup phase
- `ut-phase-02-*.md` - Test phases
- Test files in sub-workspace directory
- UT rules in sub-workspace or workspace `{docs-path}/rules/test/ut-rule.md`

---

## Execution

### Step 0: Parse Arguments & Sub-Workspace Selection

**Parse user input for sub-workspace targeting**:
1. Check if `--sub-workspace NAME` in command args
2. Check if user mentions sub-workspace name in natural language
3. If multi-sub-workspace workspace and no sub-workspace specified → Ask user which sub-workspace

**Run bash script with sub-workspace flag**:

```bash
# If sub-workspace specified:
bash .tihonspec/scripts/bash/ut/auto.sh <feature-id> --sub-workspace {SUB_WORKSPACE_NAME}

# Otherwise:
bash .tihonspec/scripts/bash/ut/auto.sh <feature-id>
```

Parse JSON output -> Store paths and flags

**⚠️ VALIDATE OUTPUT (MANDATORY):**
```
IF script exit code != 0 OR output contains "❌ Error":
  → STOP IMMEDIATELY
  → Report error message to user
  → DO NOT proceed to any later steps

IF CREATED_FEATURE_DIR == true:
  → Note: Feature folder was auto-created (UT-only task)

IF HAS_SPEC == false AND HAS_PLAN == false:
  → Must create ut-plan.md first using user's prompt as context
  → DO NOT skip to writing tests directly
```

---

### Step 0.5: Load Sub-Workspace Context (Optional)

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output into SUB_WORKSPACE_CONTEXT
3. **If SUB_WORKSPACE_CONTEXT.CONFIG_FOUND is true**:
   - **Test Framework**: Use METADATA.test_framework (vitest, jest, pytest, etc.)
   - **Test Command**: Use COMMANDS.test for execution
   - **Rules**: Load testing conventions from RULES_FILES
   - **Language**: Use METADATA.language for syntax patterns
4. **If SUB_WORKSPACE_CONTEXT.CONFIG_FOUND is false**: Auto-detect from sub-workspace files (existing behavior)
5. **If rules file not found**: Warning, continue

**Sub-Workspace Context** (use in later steps):
- Test Framework: {METADATA.test_framework}
- Test Command: {COMMANDS.test}
- Language: {METADATA.language}

---

### Step 1: Check UT Rules

**Check**: `{DOCS_PATH}/rules/test/ut-rule.md` (use DOCS_PATH from Step 0.5, default: `ai_docs`)

- **Found** -> Continue
- **Not Found** -> Ask user:
  - "UT rules not found. Create now?" (Y/N)
  - If Y: Run `/ut:create-rules` workflow first
  - If N: Continue with framework defaults

---

### Step 2: Execute Plan Phase

Run `/ut:plan` workflow internally:

1. Load templates
2. Detect framework (AI)
3. Analyze feature spec
4. Scan codebase for testable units
5. Determine test organization
6. Generate ut-plan.md
7. Generate ut-phase-*.md files

**On error** -> STOP, report to user

---

### Step 3: Execute Generate Phase

Run `/ut:generate` workflow internally:

1. Load ut-plan.md and phase files
2. Determine test file paths
3. Read source files
4. Generate test structure
5. Implement test cases
6. Implement mocks
7. Create fixtures
8. Write test files

**On error** -> STOP, report to user (plan artifacts preserved)

---

### Step 4: Run Tests

**Detect test command**:

| Framework | Command |
|-----------|---------|
| Vitest | `pnpm test` / `npm test` |
| Jest | `npm test` / `npx jest` |
| Pytest | `pytest` / `python -m pytest` |
| RSpec | `rspec` / `bundle exec rspec` |
| JUnit | `mvn test` / `gradle test` |
| xUnit | `dotnet test` |
| Go | `go test ./...` |

**Run tests** and capture output.

---

### Step 5: Output Summary

```
UT Auto Complete
=================

Feature: {feature-id}
Framework: {Vitest 3.2.4}

Artifacts Created:
  - ut-plan.md
  - ut-phase-01-setup.md
  - ut-phase-02-{name}.md (45 test cases)

Test Files Generated:
  - utils/__tests__/validator.test.ts (8 tests)
  - composables/__tests__/useCalc.test.ts (5 tests)

Test Results:
  - Total: 13 tests
  - Passed: 12
  - Failed: 1
  - Coverage: 78%

Failed Tests:
  - validator.test.ts:45 "should reject empty string"
    Expected: throw Error
    Received: undefined

Next Steps:
  1. Fix failing test in validator.test.ts:45
  2. Run `npm test` to verify
```

---

## Options

| Flag | Description |
|------|-------------|
| `--skip-run` | Plan + Generate only, skip test execution |
| `--plan-only` | Only run plan phase |
| `--force` | Overwrite existing artifacts |

---

## Error Handling

| Phase | Condition | Action |
|-------|-----------|--------|
| **Step 0** | Feature directory not found | Auto-create folder, continue |
| **Step 0** | spec.md not found | Continue - use user prompt for context |
| **Step 0** | Sub-workspace not found | **STOP** - Show available sub-workspaces |
| **Step 0** | Script non-zero exit | **STOP** - Report error, do NOT continue |
| Plan | No spec.md AND no ut-plan.md | Create ut-plan.md from user prompt first |
| Plan | templates missing | STOP - Check .tihonspec/templates/ut/ |
| Generate | ut-plan.md missing | Run ut:plan first (auto-created) |
| Run | Tests fail | Report failures, continue |
| Run | Command not found | Suggest installing test framework |

---

## Supported Frameworks

| Language | Frameworks |
|----------|------------|
| JavaScript/TypeScript | Vitest, Jest, Mocha, Jasmine |
| Python | Pytest, unittest |
| Ruby | RSpec, Minitest |
| Java | JUnit, TestNG |
| PHP | PHPUnit, Pest |
| .NET | xUnit, NUnit, MSTest |
| Go | testing, testify |

---

## Related

- `ut:create-rules` - One-time sub-workspace setup
- `ut:plan` - Create test plan only
- `ut:generate` - Generate test files only
