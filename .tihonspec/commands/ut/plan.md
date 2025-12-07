# /ut:plan - Create Unit Test Plan

## Purpose

Generate unit test plan using templates. Creates `ut-plan.md` + phase files for implementation by `/ut:generate`.

---

## Usage

```bash
/ut:plan {feature-id}                         # Create new plan
/ut:plan {feature-id} --sub-workspace {name}  # Target specific sub-workspace
/ut:plan {feature-id} --review                # Review and update existing plan
/ut:plan {feature-id} --force                 # Overwrite without asking
/ut:plan {feature-id} --standalone            # Skip feature spec, analyze codebase directly
```

### Standalone Mode (Smart Auto-Detection)

**You don't need to remember `--standalone` flag!**

When spec.md is not found, the command will **automatically ask**:
```
⚠️ Feature spec not found: .tihonspec/feature/al-223/spec.md

How would you like to proceed?
○ Create feature spec first (recommended)
○ Continue without spec (analyze codebase directly)
```

**Explicit flag still works** for automation/scripting:
```bash
/ut:plan AL-223 --standalone  # Skip prompt, go straight to standalone mode
```

In standalone mode:
- Feature directory auto-created if not exists
- spec.md NOT required
- Test requirements derived from user input + codebase analysis

---

## Output

Creates in `.tihonspec/feature/{feature-id}/`:

1. **ut-plan.md** - Main test plan (from template)
2. **ut-phase-01-setup.md** - Test setup phase
3. **ut-phase-02-{name}.md** - P1 critical tests
4. **ut-phase-03-{name}.md** - P2-P3 tests (if needed)

UT rules file location depends on sub-workspace targeting:
- **With --sub-workspace**: `{sub-workspace-root}/{docs-path}/rules/test/ut-rule.md`
- **Without**: `{workspace-root}/{docs-path}/rules/test/ut-rule.md`

---

## Templates

| Template | Location |
|----------|----------|
| Plan | `.tihonspec/templates/ut/ut-plan-template.md` |
| Phase | `.tihonspec/templates/ut/ut-phase-template.md` |

---

## Execution

### Step 0: Parse Arguments & Sub-Workspace Selection

**Parse user input for sub-workspace targeting**:
1. Check if `--sub-workspace NAME` in command args
2. Check if user mentions sub-workspace name in natural language (e.g., "for sub-workspace frontend")
3. If multi-sub-workspace workspace and no sub-workspace specified → Ask user which sub-workspace

**Run bash script with appropriate flags**:

```bash
# Standard mode:
bash .tihonspec/scripts/bash/ut/plan.sh <feature-id>

# With sub-workspace:
bash .tihonspec/scripts/bash/ut/plan.sh <feature-id> --sub-workspace {SUB_WORKSPACE_NAME}

# Standalone mode (no spec required):
bash .tihonspec/scripts/bash/ut/plan.sh <feature-id> --standalone

# Combined:
bash .tihonspec/scripts/bash/ut/plan.sh <feature-id> --sub-workspace {NAME} --standalone
```

Parse JSON output -> Store all fields including `NEEDS_STANDALONE_PROMPT`, `HAS_SPEC_FILE`, `STANDALONE_MODE`

**If NEEDS_STANDALONE_PROMPT = true** (spec.md not found, auto-detected):
- Use **AskUserQuestion** with options:
  - **Option 1**: "Create feature spec first" → STOP, instruct `/feature:specify {feature-id}`
  - **Option 2**: "Continue without spec (standalone)" → Set STANDALONE_MODE = true, continue
- This provides smart UX: user doesn't need to know `--standalone` flag exists

If error -> STOP and report to user

---

### Step 0.1: Check UT Rules

**Run check-rules script**:

```bash
# If sub-workspace specified:
bash .tihonspec/scripts/bash/ut/check-rules.sh --sub-workspace {SUB_WORKSPACE_NAME}

# Otherwise:
bash .tihonspec/scripts/bash/ut/check-rules.sh
```

Parse JSON output → Store `EXISTS`, `RULES_FILE`, `FRAMEWORK`

**If EXISTS = false**:
- Show warning:
  ```
  ⚠️ UT Rules not found: {RULES_FILE}
  ```
- Ask via AskUserQuestion:
  - **Option 1**: "Run `/ut:create-rules` first" (recommended)
  - **Option 2**: "Continue with defaults"

- If Option 1 → STOP, instruct to run create-rules
- If Option 2 → Continue with framework auto-detection

**If EXISTS = true**:
- Log: "✓ Using rules: {RULES_FILE}"
- Store FRAMEWORK for later steps

---

### Step 0.5: Load Sub-Workspace Context (Optional)

1. Sub-workspace context already loaded from Step 0 (via detect-config.sh with --sub-workspace)
2. **If CONFIG_FOUND is true**:
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

### Step 1: Load Templates

**Read**:
- `.tihonspec/templates/ut/ut-plan-template.md` -> PLAN_TEMPLATE
- `.tihonspec/templates/ut/ut-phase-template.md` -> PHASE_TEMPLATE

If missing -> STOP: "Templates not found. Check `.tihonspec/templates/ut/`"

---

### Step 2: Load UT Rules

**Check**: Rules already validated in Step 0.1

- **If EXISTS = true from Step 0.1** -> Read `{RULES_FILE}` and apply rules (naming, coverage, mocking)
- **If EXISTS = false** -> User chose to continue with defaults in Step 0.1

---

### Step 3: Detect Framework (AI)

**Scan config files using Read tool**:

| File | Framework |
|------|-----------|
| `package.json` -> devDependencies | vitest, jest, mocha, jasmine |
| `pyproject.toml` / `requirements.txt` | pytest, unittest |
| `Gemfile` | rspec, minitest |
| `pom.xml` / `build.gradle` | junit, testng |
| `composer.json` | phpunit, pest |
| `*.csproj` | xunit, nunit, mstest |
| `go.mod` | go test, testify |

**Confirm with user** via AskUserQuestion if unsure.

---

### Step 4: Analyze Feature Spec (or User Input in Standalone Mode)

**If STANDALONE_MODE = false** (standard mode):
- **Read**: `.tihonspec/feature/{feature-id}/spec.md`
- **Extract**:
  - Feature name and summary
  - Functional requirements (FR-*) -> Test scenarios
  - User stories -> Critical paths
  - Edge cases -> Boundary tests
  - Success criteria -> Coverage goals

**If STANDALONE_MODE = true** (standalone mode):
- **Ask user** via AskUserQuestion:
  - What modules/files should be tested? (e.g., "org api, org service, org repository")
  - What are the main test scenarios? (optional - can derive from code)
  - Any specific edge cases to consider? (optional)
- **Derive requirements** from Step 5 (codebase scan):
  - Public APIs -> Test scenarios
  - Method signatures -> Input/output tests
  - Error handling patterns -> Edge cases
  - Dependencies -> Mock requirements

---

### Step 5: Scan Codebase for Testable Units (AI)

**Use Glob tool to find source files**:
```
src/**/*.{ts,js,tsx,jsx}
lib/**/*.py
app/**/*.rb
**/*.go
```

**For each file, identify**:
- Functions (exported/public)
- Classes and methods
- Complexity level (simple/medium/complex)

**Use Grep to find existing tests**:
```
**/*.test.{ts,js}
**/*.spec.{ts,js}
**/test_*.py
**/*_test.go
```

**Determine test organization**:
- **>70% pattern found** -> Use automatically
- **Mixed patterns** -> Ask user preference
- **No tests found** -> Recommend framework convention

---

### Step 6: Generate UT Plan

**Read**: PLAN_TEMPLATE

**Fill placeholders**:

| Placeholder | Source |
|-------------|--------|
| `[FEATURE NAME]` | From spec.md title |
| `{feature-id}` | From bash script |
| `[DATE]` | Current date |
| `[FRAMEWORK]` | From Step 3 |
| `[VERSION]` | From config file |
| Summary | From spec.md |
| Test Organization | From Step 5 |
| Coverage Goals | From ut-rule.md or defaults |
| Critical Paths | From spec.md user stories |
| Edge Cases | From spec.md |
| Mocking Strategy | AI analysis of dependencies |
| Implementation Phases | Generated phase list |

**Write**: `.tihonspec/feature/{feature-id}/ut-plan.md`

---

### Step 7: Generate Phase Files

**Phase 01: Setup** (always created)
- Test directory structure
- Test configuration
- Shared fixtures/mocks

**Phase 02+: Test Suites** (grouped by priority)

For each phase:

1. **Read**: PHASE_TEMPLATE
2. **Fill placeholders**:

| Placeholder | Source |
|-------------|--------|
| `[XX]` | Phase number (01, 02, ...) |
| `[PHASE NAME]` | Descriptive name |
| `[P1/P2/P3/-]` | Priority level |
| `[N]` | Estimated test count |
| Objectives | From analysis |
| Test Suites | From codebase scan |
| Test Cases | From spec.md requirements |
| Mocking Required | From dependency analysis |

3. **Write**: `.tihonspec/feature/{feature-id}/ut-phase-XX-{name}.md`

**Naming convention**:
- `ut-phase-01-setup.md`
- `ut-phase-02-{component}.md` (P1)
- `ut-phase-03-{component}.md` (P2)
- `ut-phase-04-{component}.md` (P3)

---

### Step 8: Output Summary

```
UT Plan Created
===================

Framework: {name} {version}
Test Organization: {pattern}

Files created:
  - .tihonspec/feature/{id}/ut-plan.md
  - .tihonspec/feature/{id}/ut-phase-01-setup.md
  - .tihonspec/feature/{id}/ut-phase-02-{name}.md
  ...

Phases: {n} total
  - Setup: 1
  - P1 Critical: {n}
  - P2-P3: {n}

Next: /ut:generate {feature-id}
```

---

## Review Mode (`--review`)

### Step R1: Load Existing Files

**Read** all existing files:
- `ut-plan.md`
- `ut-phase-*.md`

### Step R2: Ask What to Review

**Use AskUserQuestion**:
- Test organization wrong?
- Coverage goals incorrect?
- Mocking strategy needs change?
- Phase structure needs adjustment?

### Step R3: Targeted Updates

Based on user feedback:
1. **Re-analyze** only the problematic section
2. **Preserve** correct parts
3. **Update** only what's wrong

### Step R4: Diff Preview

Show changes before saving:
```diff
- Old: Test file in __tests__/
+ New: Test file co-located with source
```

Confirm -> Update files

---

## Error Handling

| Error | Solution |
|-------|----------|
| Templates missing | Check `.tihonspec/templates/ut/` exists |
| spec.md not found | Run `/feature:specify {feature-id}` first OR use `--standalone` flag |
| No source files | Ask user for source directory |
| No framework detected | Ask user to select framework |

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
- `ut:generate` - Generate test files from plan
- `ut:auto` - Automated test workflow
