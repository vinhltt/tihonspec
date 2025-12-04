# UT Phase [XX]: [PHASE NAME]

**Priority**: [P1/P2/P3/-] | **Estimated Tests**: [N]

<!--
  This template is filled by the `/ut:plan` command.
  AI should replace all [PLACEHOLDERS] with actual values.
  Remove HTML comments after filling.
-->

## Objectives

<!--
  ACTION REQUIRED: What this phase accomplishes.
-->

1. [Primary objective]
2. [Secondary objective if any]

## Test Suites

<!--
  ACTION REQUIRED: List all test suites for this phase.
  Each suite = one test file covering one source file/module.
-->

### Suite 1: [Component/Module Name]

**Source**: `[path/to/source.ts]`
**Test File**: `[path/to/source.test.ts]`

#### Test Cases

| ID | Description | Type |
|----|-------------|------|
| TC-001 | [what it tests] | [happy \| error \| edge] |
| TC-002 | [what it tests] | [happy \| error \| edge] |

#### Mocking Required

<!--
  ACTION REQUIRED: List dependencies to mock for this suite.
  Remove if no mocking needed.
-->

- [ ] [Dependency 1] - [mock approach]
- [ ] [Dependency 2] - [mock approach]

---

### Suite 2: [Component/Module Name]

**Source**: `[path/to/source.ts]`
**Test File**: `[path/to/source.test.ts]`

#### Test Cases

| ID | Description | Type |
|----|-------------|------|
| TC-003 | [what it tests] | [happy \| error \| edge] |

#### Mocking Required

- [ ] [Dependency] - [mock approach]

---

<!--
  Add more suites as needed following the same pattern.
-->

## Expected Outcomes

- [ ] [N] test files created
- [ ] [N] test cases implemented
- [ ] All tests passing
- [ ] Coverage target met for this phase
