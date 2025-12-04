# /ut:generate - Generate Unit Test Files

## Purpose

Generate executable unit test code based on the UT plan. Creates test files with test cases, assertions, mocks, and fixtures following project conventions.

---

## Input

- **ut-plan.md** - Test organization, coverage goals, mocking strategy
- **ut-phase-*.md** - Phase files with test suites and cases

---

## Output

Creates test files in project directory:

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

### Step 0: Run Bash Script

```bash
bash .tihonspec/scripts/bash/ut/generate.sh <feature-id>
```

Parse JSON output -> Store `FEATURE_DIR`, `UT_PLAN_FILE`

If error -> STOP and report to user

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
| Separate project | `MyProject.Tests/CalcTests.cs` |

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
