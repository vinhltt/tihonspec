# /ut:generate - Generate Unit Test Files

## Purpose

Generate executable unit test code based on the UT plan. Creates test files with test cases, assertions, mocks, and fixtures following sub-workspace conventions.

---

## Usage

```bash
/ut:generate {feature-id}                         # Generate tests
/ut:generate {feature-id} --sub-workspace {name}  # Target specific sub-workspace
```

---

## Input

- **ut-plan.md** - Test organization, coverage goals, mocking strategy
- **ut-phase-*.md** - Phase files with test suites and cases
- **ut-rule.md** - From sub-workspace or workspace (based on --sub-workspace flag)

---

## Output

Creates test files in sub-workspace directory:

| Framework | Pattern |
|-----------|---------|
| Jest/Vitest | `*.test.{ts,js}` or `*.spec.{ts,js}` |
| Pytest | `test_*.py` or `*_test.py` |
| RSpec | `*_spec.rb` |
| JUnit | `*Test.java` |
| xUnit/NUnit | `*Tests.cs` |
| Go | `*_test.go` |

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
bash .tihonspec/scripts/bash/ut/generate.sh <feature-id> --sub-workspace {SUB_WORKSPACE_NAME}

# Otherwise:
bash .tihonspec/scripts/bash/ut/generate.sh <feature-id>
```

Parse JSON output -> Store `FEATURE_DIR`, `UT_PLAN_FILE`, `UT_RULES_FILE`

If error -> STOP and report to user

---

### Step 0.1: Validate UT Rules (Required)

**Run check-rules script**:

```bash
# If sub-workspace specified:
bash .tihonspec/scripts/bash/ut/check-rules.sh --sub-workspace {SUB_WORKSPACE_NAME}

# Otherwise:
bash .tihonspec/scripts/bash/ut/check-rules.sh
```

Parse JSON output → Store `EXISTS`, `RULES_FILE`, `FRAMEWORK`, `COVERAGE_TARGET`

**If EXISTS = false**:
- Show error:
  ```
  ❌ UT Rules Required
  =====================
  Cannot generate tests without UT rules.

  Expected: {RULES_FILE}

  💡 Run these commands first:
     1. /ut:create-rules --sub-workspace {SUB_WORKSPACE_NAME}
     2. /ut:generate {feature-id} --sub-workspace {SUB_WORKSPACE_NAME}
  ```
- **STOP** - Do not continue

**If EXISTS = true**:
- Log: "✓ Rules loaded: {RULES_FILE}"
- Store FRAMEWORK, COVERAGE_TARGET for later steps
- Continue to Step 1

---

### Step 0.5: Load Sub-Workspace Context (Optional)

1. Sub-workspace context already loaded from Step 0 (via detect-config.sh with --sub-workspace)
2. **If CONFIG_FOUND is true**:
   - **Test Framework**: Use METADATA.test_framework (vitest, jest, pytest, etc.)
   - **Test Command**: Use COMMANDS.test for execution
   - **Rules**: Load testing conventions from RULES_FILES
   - **Language**: Use METADATA.language for syntax patterns
4. **If SUB_WORKSPACE_CONTEXT.CONFIG_FOUND is false**: Auto-detect from sub-workspace files (existing behavior)
5. **If rules file not found**: Already handled in Step 0.1 (error, stopped)

**Sub-Workspace Context** (use in later steps):
- Test Framework: {METADATA.test_framework}
- Test Command: {COMMANDS.test}
- Language: {METADATA.language}

---

### Step 1: Load Plan and Phases

**Read from FEATURE_DIR**:
- `ut-plan.md` - For framework, test organization, mocking strategy
- `ut-phase-*.md` - For test suites and test cases

**Extract from ut-plan.md**:
- Framework and version
- Test organization pattern (co-located, __tests__/, tests/)
- File naming convention
- Global mocking strategy

**Extract from phase files**:
- Test suites (source file, test file path)
- Test cases (TC-* with descriptions and types)
- Per-suite mocking requirements

If `ut-plan.md` missing -> "Run `/ut:plan {feature-id}` first"

---

### Step 2: Determine Test Paths (AI)

**From ut-plan.md "Test Organization" section**:

| Pattern Type | Example |
|--------------|---------|
| `/tests/` directory | `/tests/composables/useCalc.test.ts` |
| `__tests__/` subdirs | `composables/__tests__/useCalc.test.ts` |
| Co-located | `composables/useCalc.spec.ts` |
| Separate test directory | `MyProject.Tests/CalcTests.cs` |

Apply pattern to each source file in phases.

---

### Step 3: Read Source Files (AI)

For each test suite in phase files:

1. **Read source file** to understand actual implementation
2. **Extract**:
   - Function signatures and return types
   - Class methods and properties
   - Dependencies to mock
3. **Identify edge cases** from actual code logic

---

### Step 4: Generate Test Structure

**Template for Jest/Vitest**:
```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest'
import { FunctionName } from '../path'

// Mocks
vi.mock('../dependency')

describe('FunctionName', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('should {test case from TC-001}', () => {
    // Arrange - from "Given"
    // Act - from "When"
    // Assert - from "Then"
  })
})
```

**Template for Pytest**:
```python
import pytest
from unittest.mock import patch
from module import function_name

class TestFunctionName:
    @pytest.fixture
    def setup(self):
        return function_name()

    def test_case_from_tc001(self, setup):
        # Arrange - from "Given"
        # Act - from "When"
        # Assert - from "Then"
```

---

### Step 5: Implement Test Cases

For each TC-* in phase files:

| ID | Description | Type |
|----|-------------|------|
| TC-001 | Should calculate total | happy |

Generate:

```typescript
it('should calculate total', () => {
  // Arrange
  const cart = new Cart()
  cart.add({ price: 10 })
  cart.add({ price: 20 })

  // Act
  const total = cart.calculateTotal()

  // Assert
  expect(total).toBe(30)
})
```

---

### Step 6: Implement Mocks

**From ut-plan.md "Mocking Strategy" + phase "Mocking Required"**:

| Dependency | Mock Implementation |
|------------|---------------------|
| External API | `vi.mock('./api', () => ({ call: vi.fn() }))` |
| Database | In-memory mock or mock repository |
| File system | `vi.spyOn(fs, 'readFile')` |
| Time/Date | `vi.useFakeTimers()` |

---

### Step 7: Create Fixtures

If tests share data, create fixture files:

```typescript
// fixtures/users.ts
export const validUser = {
  id: 1,
  name: 'Test User',
  email: 'test@example.com'
}

export const invalidUser = {
  id: -1,
  name: '',
  email: 'invalid'
}
```

---

### Step 8: Write Files

1. Create directories if needed
2. Write test files with proper formatting
3. Write fixture files if created

---

### Step 9: Output Summary

```
Test Files Generated
=====================

Framework: {Vitest 3.2.4}
Pattern: {__tests__/ subdirectories}

Files Created:
  - composables/__tests__/useCalc.test.ts (5 tests)
  - utils/__tests__/validator.test.ts (3 tests)
  - fixtures/users.ts

Total: 8 test cases

Mocks:
  - External API (vi.mock)
  - Database (mock repository)

Next: Run tests with `npm test` or `pnpm test`
```

---

## Quality Checklist

- [ ] All TC-* from phase files implemented
- [ ] Mocks isolate external dependencies
- [ ] Assertions are meaningful (not just `toBeDefined`)
- [ ] Edge cases covered
- [ ] Code follows framework conventions
- [ ] Imports are correct
- [ ] Generated code is syntactically valid

---

## Error Handling

| Error | Solution |
|-------|----------|
| ut-plan.md missing | Run `/ut:plan {feature-id}` first |
| ut-phase-*.md missing | Run `/ut:plan {feature-id}` first |
| Source file not found | Skip that suite, continue with others |
| Framework not detected | Ask user to specify |

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

- `ut:plan` - Create test plan (run first)
- `ut:auto` - Automated workflow (plan + generate + run)
