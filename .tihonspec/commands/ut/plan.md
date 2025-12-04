# /ut:plan - Create Unit Test Plan

## Purpose

Generate unit test plan using templates. Creates `ut-plan.md` + phase files for implementation by `/ut:generate`.

---

## Usage

```bash
/ut:plan {feature-id}           # Create new plan
/ut:plan {feature-id} --review  # Review and update existing plan
/ut:plan {feature-id} --force   # Overwrite without asking
```

---

## Output

Creates in `.tihonspec/feature/{feature-id}/`:

1. **ut-plan.md** - Main test plan (from template)
2. **ut-phase-01-setup.md** - Test setup phase
3. **ut-phase-02-{name}.md** - P1 critical tests
4. **ut-phase-03-{name}.md** - P2-P3 tests (if needed)

---

## Templates

| Template | Location |
|----------|----------|
| Plan | `.tihonspec/templates/ut/ut-plan-template.md` |
| Phase | `.tihonspec/templates/ut/ut-phase-template.md` |

---

## Execution

### Step 0: Run Bash Script

```bash
bash .tihonspec/scripts/bash/ut/plan.sh <feature-id>
```

Parse JSON output -> Store `FEATURE_DIR`, `SPEC_FILE`, `MODE`

If error -> STOP and report to user

---

### Step 1: Load Templates

**Read**:
- `.tihonspec/templates/ut/ut-plan-template.md` -> PLAN_TEMPLATE
- `.tihonspec/templates/ut/ut-phase-template.md` -> PHASE_TEMPLATE

If missing -> STOP: "Templates not found. Check `.tihonspec/templates/ut/`"

---

### Step 2: Load UT Rules (If Available)

**Check**: `docs/rules/test/ut-rule.md`

- **Found** -> Read and apply rules (naming, coverage, mocking)
- **Not Found** -> Ask: "Run `/ut:create-rules` first?" or continue with defaults

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

### Step 4: Analyze Feature Spec

**Read**: `.tihonspec/feature/{feature-id}/spec.md`

**Extract**:
- Feature name and summary
- Functional requirements (FR-*) -> Test scenarios
- User stories -> Critical paths
- Edge cases -> Boundary tests
- Success criteria -> Coverage goals

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
| spec.md not found | Run `/feature:specify {feature-id}` first |
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

- `ut:create-rules` - One-time project setup
- `ut:generate` - Generate test files from plan
- `ut:auto` - Automated test workflow
