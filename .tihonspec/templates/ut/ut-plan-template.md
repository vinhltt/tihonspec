# Unit Test Plan: [FEATURE NAME]

**Feature**: `{feature-id}` | **Date**: [DATE] | **Spec**: `.tihonspec/feature/{feature-id}/spec.md`
**Framework**: [FRAMEWORK] | **Version**: [VERSION]

<!--
  This template is filled by the `/ut:plan` command.
  AI should replace all [PLACEHOLDERS] with actual values.
  Remove HTML comments after filling.
-->

## Summary

<!--
  ACTION REQUIRED: Extract from spec.md - what tests will cover.
  Keep it brief (2-3 sentences).
-->

[Brief description of testing scope based on feature spec]

## Test Organization

<!--
  ACTION REQUIRED: Detect from existing tests or ask user preference.
-->

| Setting | Value |
|---------|-------|
| **Pattern** | [co-located \| __tests__/ \| tests/] |
| **File Naming** | [*.test.ts \| *.spec.ts \| test_*.py] |
| **Source** | [existing-tests \| framework-convention \| user-preference] |

## Coverage Goals

<!--
  ACTION REQUIRED: From ut-rule.md or use defaults.
-->

| Priority | Target | Scope |
|----------|--------|-------|
| P1 Critical | 90%+ | [public APIs, core business logic] |
| P2 Important | 80%+ | [internal services, utilities] |
| P3 Supporting | 70%+ | [helpers, edge cases] |

### Critical Paths

<!--
  ACTION REQUIRED: Extract from spec.md user stories.
-->

1. [Happy path from US-001]
2. [Happy path from US-002]

### Edge Cases

<!--
  ACTION REQUIRED: Extract from spec.md edge cases section.
-->

1. [Edge case 1]
2. [Edge case 2]

## Mocking Strategy

<!--
  ACTION REQUIRED: Analyze dependencies from codebase scan.
  Remove sections that don't apply.
-->

### External Services

| Service | Mock Approach |
|---------|---------------|
| [API name] | [vi.mock / jest.mock / patch] |

### Database

- **Strategy**: [in-memory \| mock repository \| test DB]
- **Fixtures**: [location of test data]

### Time/Date

- **Strategy**: [vi.useFakeTimers() \| freezegun \| manual mock]

### File System

- **Strategy**: [virtual fs \| temp directory \| mock]

## Implementation Phases

<!--
  ACTION REQUIRED: List all phase files that will be generated.
  Phase 01 is always setup. Subsequent phases grouped by priority.
-->

| Phase | Name | Priority | Tests | File |
|-------|------|----------|-------|------|
| 01 | Setup | - | - | `ut-phase-01-setup.md` |
| 02 | [component] | P1 | [n] | `ut-phase-02-[name].md` |
| 03 | [component] | P2 | [n] | `ut-phase-03-[name].md` |

## Quality Checklist

- [ ] All FR-* from spec.md have test coverage planned
- [ ] Edge cases from spec.md included in phases
- [ ] Mocking strategy covers all external dependencies
- [ ] Coverage goals are realistic (70-90% range)
- [ ] Phase files created and complete

## Next Step

Run `/ut:generate {feature-id}` to create test files
