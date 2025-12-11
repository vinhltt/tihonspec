# /ut:create-rules - Create/Update Sub-Workspace UT Standards

## Purpose

Generate or update sub-workspace-wide unit testing standards (`ut-rule.md`). Initial setup or refresh when codebase patterns change.

## Usage

```
/ut:create-rules [--sub-workspace NAME] [--update]
```

**Flags**:
- `--sub-workspace NAME`: Target specific sub-workspace
- `--update`: Update existing rules (skip prompts, show comparison)

---

## Output

Creates `{OUTPUT_ROOT}/{OUTPUT_DOCS_PATH}/rules/test/ut-rule.md`
- **With --sub-workspace**: Sub-workspace-specific path (e.g., `apps/frontend/{docs.path}/rules/test/ut-rule.md`)
- **Without --sub-workspace**: Workspace path (e.g., `{docs.path}/rules/test/ut-rule.md`)
- **docs.path**: From `.tihonspec.yaml` config (default: `ai_docs`)

---

## Execution

### Step 0: Parse Arguments & Sub-Workspace Selection

**Parse user input**:
1. Check if `--update` flag in command args → Store `UPDATE_MODE = true`
2. Check if `--sub-workspace NAME` in command args
3. Check if user mentions sub-workspace name in natural language (e.g., "for sub-workspace frontend")
4. If multi-sub-workspace workspace detected (SUB_WORKSPACES array not empty) and no sub-workspace specified:
   - Ask user: "Which sub-workspace?" with AskUserQuestion
   - Options: List from SUB_WORKSPACES[].name

**Run bash script with sub-workspace flag**:

```bash
# If sub-workspace specified or detected:
bash .tihonspec/scripts/bash/ut/create-rules.sh --sub-workspace {SUB_WORKSPACE_NAME}

# Otherwise (standalone workspace):
bash .tihonspec/scripts/bash/ut/create-rules.sh
```

**CRITICAL: Handle script errors**:
- **If exit code != 0**: **STOP IMMEDIATELY**. Do NOT continue or try workarounds.
- **If "Required tools not installed"**: Show error message to user and STOP. User must install prerequisites first.
- **If other errors**: Show error message and STOP.

**On success only**: Parse JSON output → Store `RULES_FILE`, `TEMPLATE_FILE`, `MODE`, `OUTPUT_ROOT`, `SUB_WORKSPACES`

**Handle existing rules**:
- If `UPDATE_MODE = true` AND `MODE != "exists"`:
  - Error: "No existing ut-rule.md found. Run without --update to create."
  - STOP
- If `MODE = "exists"` AND `UPDATE_MODE = false`:
  - Ask via AskUserQuestion: "ut-rule.md already exists"
    - **Update**: Show comparison, replace if confirmed
    - **Replace**: Skip comparison, regenerate from scratch
    - **Cancel**: Stop execution
- If `MODE = "exists"` AND `UPDATE_MODE = true`:
  - Proceed directly to update flow (skip prompt)

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

### Step 1: Detect Framework (AI)

**Scan config files using Read tool**:

| File | Framework | Language |
|------|-----------|----------|
| `package.json` → devDependencies | vitest, jest, mocha, jasmine | JavaScript/TypeScript |
| `pyproject.toml` / `requirements.txt` | pytest, unittest | Python |
| `Gemfile` | rspec, minitest | Ruby |
| `pom.xml` / `build.gradle` | junit, testng | Java |
| `composer.json` | phpunit, pest | PHP |
| `*.csproj` | xunit, nunit, mstest | C# |
| `go.mod` | testing, testify | Go |

**Ask user** via AskUserQuestion:
- Detected: "{Framework}" for {Language} - Use this?
- Or select from supported frameworks

---

### Step 2: Scan Existing Tests (AI)

**Use Glob tool** (language-specific patterns):

| Language | Patterns |
|----------|----------|
| JS/TS | `**/*.test.{ts,js}`, `**/*.spec.{ts,js}` |
| Python | `**/test_*.py`, `**/*_test.py` |
| Ruby | `**/*_spec.rb` |
| Java | `**/Test*.java`, `**/*Test.java` |
| C# | `**/*Tests.cs`, `**/*Test.cs` |
| PHP | `**/*Test.php` |
| Go | `**/*_test.go` |

**If found**: Read 3-5 samples, analyze patterns

**Ask**: Follow existing patterns? (Yes / Customize / Ignore)

---

### Step 3: Gather Preferences

**Ask via AskUserQuestion**:
1. **Naming**: Framework default / Custom
2. **Organization**: Co-located / Separate directory / Test project
3. **Coverage**: 80% / 70% / 90% / Custom
4. **Mocking**: Framework default / Manual / Mixed

---

### Step 4: Fill Template Placeholders

**Read** `{TEMPLATE_FILE}` and fill based on detected framework:

#### Placeholder Reference

| Placeholder | JS/TS (Vitest) | Python (Pytest) | C# (xUnit) | Go |
|-------------|----------------|-----------------|------------|-----|
| `[LANGUAGE]` | TypeScript | Python | C# | Go |
| `[LANGUAGE_EXT]` | typescript | python | csharp | go |
| `[FILE_PATTERN]` | `*.test.ts` | `test_*.py` | `*Tests.cs` | `*_test.go` |
| `[TEST_CASE_PATTERN]` | `should {action}` | `test_{action}` | `{Action}_Should_{Result}` | `Test{Action}` |
| `[IMPORT_STATEMENT]` | `import { describe, it, expect } from 'vitest'` | `import pytest` | `using Xunit;` | `import "testing"` |
| `[MATCHER]` (equality) | `toBe()` | `assert x == y` | `Assert.Equal()` | `assert.Equal()` |
| `[MATCHER]` (error) | `toThrow()` | `pytest.raises()` | `Assert.Throws<>()` | `assert.Panics()` |
| `[MOCK_METHOD]` | `vi.mock()` | `@patch` | `Mock<T>` | `mockery` |
| `[LIFECYCLE_EXAMPLE]` | `beforeEach(() => {})` | `@pytest.fixture` | `IClassFixture<T>` | `func TestMain(m)` |

---

### Step 5: Generate Examples

**Generate 3 examples** in detected language:

1. **Basic Test** - Simple function test
2. **Error Handling** - Exception/error test
3. **Async with Mock** - Mocking external dependency

---

### Step 6: Save & Confirm

**If UPDATE mode** (user selected "Update" OR `--update` flag):

1. Read existing `{RULES_FILE}` content
2. Extract key fields from existing rules:
   - Framework name & version
   - File pattern
   - Coverage target
   - Test file count (from Glob)
3. Show comparison table:

```
📊 UT Rules Comparison
┌─────────────────┬──────────────────┬──────────────────┐
│ Field           │ Current          │ Detected         │
├─────────────────┼──────────────────┼──────────────────┤
│ Framework       │ {current}        │ {detected}       │
│ File Pattern    │ {current}        │ {detected}       │
│ Coverage Target │ {current}        │ {detected}       │
│ Test Files      │ {current_count}  │ {detected_count} │
└─────────────────┴──────────────────┴──────────────────┘

{If differences found}:
⚠️  Changes detected: {list changed fields}
```

4. Ask via AskUserQuestion: "Replace existing rules with new version?"
   - **Yes**: Proceed to save
   - **No**: Cancel, keep existing

**If CREATE mode** (new file):

1. Preview first 30 lines
2. Confirm → Write to `{RULES_FILE}`

**Save**:
- Write generated content to `{RULES_FILE}`
- Update "Last Updated" date in file

**Output**:
```
# If created:
✅ UT Rules created: {RULES_FILE}

# If updated:
✅ UT Rules updated: {RULES_FILE}
   Changed: {list of changed fields}

Language: {language}
Framework: {name} {version}
Next: /ut:plan {feature-id}
```

---

## Supported Frameworks

| Language | Frameworks | File Pattern | Test Pattern |
|----------|------------|--------------|--------------|
| JavaScript/TypeScript | Vitest, Jest, Mocha | `*.test.ts` | `should {action}` |
| Python | Pytest, unittest | `test_*.py` | `test_{action}` |
| Ruby | RSpec, Minitest | `*_spec.rb` | `it {behavior}` |
| Java | JUnit, TestNG | `*Test.java` | `@Test void test{Action}` |
| PHP | PHPUnit, Pest | `*Test.php` | `test{Action}()` |
| C# | xUnit, NUnit, MSTest | `*Tests.cs` | `[Fact] {Action}_Should_{Result}` |
| Go | testing, testify | `*_test.go` | `func Test{Action}(t)` |

---

## Related

- `ut:plan` - Create test plan
- `ut:generate` - Generate tests
- `ut:auto` - Automated workflow
