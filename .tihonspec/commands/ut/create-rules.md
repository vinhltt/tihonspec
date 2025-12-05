# /ut:create-rules - Create Project UT Standards

## Purpose

Generate project-wide unit testing standards (`ut-rule.md`). One-time setup defining conventions, coverage, mocking.

---

## Output

Creates `{OUTPUT_ROOT}/{OUTPUT_DOCS_PATH}/rules/test/ut-rule.md`
- **With --project**: Project-specific path (e.g., `apps/frontend/ai_docs/rules/test/ut-rule.md`)
- **Without --project**: Workspace path (e.g., `ai_docs/rules/test/ut-rule.md`)

---

## Execution

### Step 0: Parse Arguments & Project Selection

**Parse user input for project targeting**:
1. Check if `--project NAME` in command args
2. Check if user mentions project name in natural language (e.g., "for project frontend")
3. If multi-project workspace detected (PROJECTS array not empty) and no project specified:
   - Ask user: "Which project?" with AskUserQuestion
   - Options: List from PROJECTS[].name

**Run bash script with project flag**:

```bash
# If project specified or detected:
bash .tihonspec/scripts/bash/ut/create-rules.sh --project {PROJECT_NAME}

# Otherwise (standalone workspace):
bash .tihonspec/scripts/bash/ut/create-rules.sh
```

Parse JSON output → Store `RULES_FILE`, `TEMPLATE_FILE`, `MODE`, `OUTPUT_ROOT`, `PROJECTS`

If `MODE` = "exists" → Ask: Update / Replace / Cancel

---

### Step 0.5: Load Project Context (Optional)

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output into PROJECT_CONTEXT
3. **If PROJECT_CONTEXT.CONFIG_FOUND is true**:
   - **Test Framework**: Use METADATA.test_framework (vitest, jest, pytest, etc.)
   - **Test Command**: Use COMMANDS.test for execution
   - **Rules**: Load testing conventions from RULES_FILES
   - **Language**: Use METADATA.language for syntax patterns
4. **If PROJECT_CONTEXT.CONFIG_FOUND is false**: Auto-detect from project files (existing behavior)
5. **If rules file not found**: Warning, continue

**Project Context** (use in later steps):
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

1. Preview first 30 lines
2. Confirm → Write to `{RULES_FILE}`

**Output**:
```
UT Rules created: {RULES_FILE}
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
