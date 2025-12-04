# Unit Test Workflow Guide

Hướng dẫn sử dụng bộ commands UT (Unit Test) trong `.tihonspec` framework.

---

## Tổng Quan

### Workflow Đơn Giản

```
┌─────────────────┐     ┌─────────────┐     ┌──────────────┐
│ ut:create-rules │ ──► │   ut:plan   │ ──► │ ut:generate  │
│   (1 lần duy)   │     │ (mỗi feature)│     │ (tạo tests)  │
└─────────────────┘     └─────────────┘     └──────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │    ut:auto      │
                    │ (tự động tất cả)│
                    └─────────────────┘
```

### 4 Commands Chính

| Command | Mục đích | Khi nào dùng |
|---------|----------|--------------|
| `ut:create-rules` | Tạo UT rules cho project | 1 lần khi setup project |
| `ut:plan` | Tạo test plan từ spec | Mỗi feature cần test |
| `ut:generate` | Tạo test files từ plan | Sau khi có plan |
| `ut:auto` | Chạy tự động tất cả | Muốn nhanh, không review |

---

## Commands Chi Tiết

### 1. `/ut:create-rules` - Setup Project (1 lần)

**Mục đích**: Tạo file `docs/rules/test/ut-rule.md` định nghĩa conventions cho toàn project.

**Cách dùng**:
```bash
/ut:create-rules
```

**Quá trình**:
1. AI scan config files để detect framework (package.json, pyproject.toml, *.csproj, ...)
2. AI scan existing tests để detect patterns
3. Hỏi bạn preferences (naming, coverage, organization, mocking)
4. Tạo `ut-rule.md` với conventions đã chọn

**Output**:
- `docs/rules/test/ut-rule.md`

**Ví dụ output**:
```
UT Rules created: docs/rules/test/ut-rule.md
Language: TypeScript
Framework: Vitest 3.2.4
Next: /ut:plan {feature-id}
```

---

### 2. `/ut:plan` - Tạo Test Plan

**Mục đích**: Tạo kế hoạch test chi tiết từ feature spec.

**Cách dùng**:
```bash
# Tạo plan mới
/ut:plan pref-001

# Review và update plan đã có
/ut:plan pref-001 --review

# Ghi đè không hỏi
/ut:plan pref-001 --force
```

**Yêu cầu trước**:
- Phải có `spec.md` trong `.tihonspec/feature/{feature-id}/`
- Chạy `/feature.tihonspec {feature-id}` nếu chưa có

**Quá trình**:
1. Load UT rules (nếu có)
2. Detect framework từ config files
3. Analyze feature spec (`spec.md`)
4. Scan codebase tìm testable units
5. Xác định test organization (co-located, __tests__, tests/)
6. Tạo 3 files output

**Output** (trong `.tihonspec/feature/{feature-id}/`):
- `test-spec.md` - Test scenarios và test cases
- `coverage-analysis.md` - Phân tích code chưa có test
- `test-plan.md` - Kế hoạch implementation

**Ví dụ output**:
```
Test Plan Created
===================

Framework: Vitest 3.2.4
Test Scenarios: 12 scenarios, 45 test cases
Coverage Gaps: 8 untested units (5 high priority)

Files created:
  - .tihonspec/feature/pref-001/test-spec.md
  - .tihonspec/feature/pref-001/coverage-analysis.md
  - .tihonspec/feature/pref-001/test-plan.md

Next: /ut:generate pref-001
```

---

### 3. `/ut:generate` - Tạo Test Files

**Mục đích**: Tạo actual test files từ plan đã có.

**Cách dùng**:
```bash
/ut:generate pref-001
```

**Yêu cầu trước**:
- Phải có `test-plan.md` trong feature directory
- Chạy `/ut:plan {feature-id}` nếu chưa có

**Quá trình**:
1. Load plan và spec files
2. Xác định test file paths từ organization pattern
3. Read source files để hiểu implementation
4. Generate test structure với imports, mocks
5. Implement test cases từ TC-* trong spec
6. Tạo fixtures nếu cần
7. Write test files

**Output**:
- Test files trong project (e.g., `*.test.ts`, `test_*.py`)
- Fixture files nếu có

**Ví dụ output**:
```
Test Files Generated
=====================

Framework: Vitest 3.2.4
Pattern: __tests__/ subdirectories

Files Created:
  - composables/__tests__/useCalc.test.ts (5 tests)
  - utils/__tests__/validator.test.ts (3 tests)
  - fixtures/users.ts

Total: 8 test cases

Next: Run tests with `npm test` or `pnpm test`
```

---

### 4. `/ut:auto` - Tự Động Tất Cả

**Mục đích**: Chạy toàn bộ workflow một lệnh (plan → generate → run tests).

**Cách dùng**:
```bash
# Full workflow
/ut:auto pref-001

# Chỉ plan + generate, không run
/ut:auto pref-001 --skip-run

# Chỉ plan
/ut:auto pref-001 --plan-only

# Ghi đè artifacts cũ
/ut:auto pref-001 --force
```

**Quá trình**:
1. Check UT rules (tạo nếu chưa có)
2. Execute `/ut:plan` workflow
3. Execute `/ut:generate` workflow
4. Run tests và report results

**Output**:
```
UT Auto Complete
=================

Feature: pref-001
Framework: Vitest 3.2.4

Artifacts Created:
  - test-spec.md (12 scenarios, 45 test cases)
  - coverage-analysis.md (8 gaps identified)
  - test-plan.md (15 implementation tasks)

Test Files Generated:
  - utils/__tests__/validator.test.ts (8 tests)
  - composables/__tests__/useCalc.test.ts (5 tests)

Test Results:
  - Total: 13 tests
  - Passed: 12
  - Failed: 1
  - Coverage: 78%
```

---

## Use Cases

### Use Case 1: Setup Project Mới

**Tình huống**: Bắt đầu project mới, chưa có tests.

```bash
# 1. Tạo UT rules cho project
/ut:create-rules

# 2. Tạo feature spec (nếu chưa có)
/feature.tihonspec pref-001

# 3. Tạo test plan
/ut:plan pref-001

# 4. Tạo test files
/ut:generate pref-001

# 5. Run tests
npm test
```

---

### Use Case 2: Nhanh - Không Cần Review

**Tình huống**: Cần tạo tests nhanh, tin tưởng AI.

```bash
# Một lệnh chạy tất cả
/ut:auto pref-001
```

---

### Use Case 3: Project Đã Có Tests

**Tình huống**: Project đã có test files, muốn thêm tests cho feature mới.

```bash
# AI sẽ detect existing patterns và follow
/ut:plan pref-002
/ut:generate pref-002
```

AI sẽ:
- Scan existing tests để học patterns
- Follow naming convention đang dùng
- Đặt test files đúng location

---

### Use Case 4: Review Thấy Plan Sai

**Tình huống**: Đã chạy `/ut:plan`, nhưng review thấy plan không đúng.

```bash
# Cách 1: Review mode - chỉ fix phần sai
/ut:plan pref-001 --review
# → AI hỏi phần nào sai, chỉ update phần đó

# Cách 2: Force - tạo lại từ đầu
/ut:plan pref-001 --force
```

---

### Use Case 5: Thêm File Vào Scope

**Tình huống**: Plan đã tạo nhưng quên include 1 file.

```bash
# Chạy lại plan với --review
/ut:plan pref-001 --review

# Khi được hỏi, chọn "Coverage gaps missing"
# AI sẽ re-scan và add missing files
```

---

### Use Case 6: Thay Đổi Test Organization

**Tình huống**: Muốn đổi từ `__tests__/` sang co-located.

```bash
# 1. Chạy review mode
/ut:plan pref-001 --review

# 2. Chọn "Test organization wrong"

# 3. AI hỏi organization mới
# → Chọn "Co-located"

# 4. AI update plan với organization mới

# 5. Re-generate tests
/ut:generate pref-001
```

---

### Use Case 7: Multi-Language Project

**Tình huống**: Project có cả TypeScript và Python.

```bash
# UT rules sẽ detect primary language
# Nếu cần tạo rules riêng cho từng language:

# 1. Setup cho TypeScript
/ut:create-rules
# → Chọn Vitest

# 2. Với Python feature, AI tự detect
/ut:plan python-feature-001
# → AI detect pytest từ pyproject.toml
```

---

### Use Case 8: CI/CD Integration

**Tình huống**: Muốn tạo tests trong CI pipeline.

```bash
# Sử dụng --force để không có interactive prompts
/ut:auto pref-001 --force --skip-run

# Sau đó CI chạy tests
npm test -- --coverage
```

---

### Use Case 9: Tests Fail - Cần Fix

**Tình huống**: Generated tests fail, cần điều chỉnh.

**Option A: Fix manually**
- Edit test files trực tiếp
- AI tạo ra syntactically correct code, có thể cần tune assertions

**Option B: Regenerate với hints**
```bash
# 1. Review plan để đảm bảo đúng
/ut:plan pref-001 --review

# 2. Describe issue khi được hỏi
# "Mocking strategy cần thay đổi - API mock không đúng response format"

# 3. Regenerate
/ut:generate pref-001
```

---

### Use Case 10: Partial Generation

**Tình huống**: Chỉ muốn tạo tests cho 1 file cụ thể.

```bash
# 1. Tạo plan full
/ut:plan pref-001

# 2. Edit test-plan.md manually
# → Chỉ giữ lại tasks cho file cần test

# 3. Generate
/ut:generate pref-001
# → AI chỉ tạo tests cho tasks còn lại trong plan
```

---

## Supported Frameworks

| Language | Frameworks | File Pattern | Test Command |
|----------|------------|--------------|--------------|
| TypeScript/JavaScript | Vitest, Jest, Mocha | `*.test.ts` | `npm test` |
| Python | Pytest, unittest | `test_*.py` | `pytest` |
| Ruby | RSpec, Minitest | `*_spec.rb` | `rspec` |
| Java | JUnit, TestNG | `*Test.java` | `mvn test` |
| PHP | PHPUnit, Pest | `*Test.php` | `./vendor/bin/phpunit` |
| C# | xUnit, NUnit, MSTest | `*Tests.cs` | `dotnet test` |
| Go | testing, testify | `*_test.go` | `go test ./...` |

---

## File Structure

```
project/
├── docs/
│   └── rules/
│       └── test/
│           └── ut-rule.md          ← UT Rules (1 per project)
│
├── .tihonspec/
│   ├── feature/
│   │   └── pref-001/
│   │       ├── spec.md             ← Feature spec
│   │       ├── test-spec.md        ← Test scenarios (from ut:plan)
│   │       ├── coverage-analysis.md ← Coverage gaps (from ut:plan)
│   │       └── test-plan.md        ← Implementation plan (from ut:plan)
│   │
│   ├── commands/
│   │   └── ut/
│   │       ├── create-rules.md
│   │       ├── plan.md
│   │       ├── generate.md
│   │       └── auto.md
│   │
│   ├── scripts/
│   │   └── bash/
│   │       └── ut/
│   │           ├── create-rules.sh
│   │           ├── plan.sh
│   │           ├── generate.sh
│   │           └── auto.sh
│   │
│   └── templates/
│       └── ut-rule-template.md     ← Template for UT rules
│
└── src/                            ← Your source code
    ├── utils/
    │   ├── validator.ts
    │   └── __tests__/
    │       └── validator.test.ts   ← Generated test (from ut:generate)
    └── ...
```

---

## Troubleshooting

### Error: "spec.md not found"

**Nguyên nhân**: Chưa có feature spec.

**Giải pháp**:
```bash
/feature.tihonspec pref-001
```

---

### Error: "test-plan.md not found"

**Nguyên nhân**: Chưa chạy plan.

**Giải pháp**:
```bash
/ut:plan pref-001
```

---

### Error: "Framework not detected"

**Nguyên nhân**: Không tìm thấy config file (package.json, pyproject.toml, ...).

**Giải pháp**:
- Đảm bảo có config file trong project root
- Hoặc AI sẽ hỏi bạn chọn framework manually

---

### Generated tests không compile

**Nguyên nhân**: AI không có đủ context về source code.

**Giải pháp**:
1. Đảm bảo source files được read correctly
2. Review test-plan.md để check imports
3. Manually fix compile errors
4. Hoặc regenerate với `/ut:generate pref-001`

---

### Tests fail với wrong assertions

**Nguyên nhân**: AI dự đoán expected values không đúng.

**Giải pháp**:
1. Review test-spec.md - expected values có đúng không?
2. Nếu sai, update test-spec.md manually
3. Regenerate với `/ut:generate pref-001`
4. Hoặc fix assertions trong test files directly

---

### Coverage không đạt target

**Nguyên nhân**: Plan không cover hết code.

**Giải pháp**:
```bash
# Review lại coverage analysis
/ut:plan pref-001 --review
# Chọn "Coverage gaps missing"
```

---

## Tips & Best Practices

### 1. Luôn review plan trước khi generate

```bash
/ut:plan pref-001
# → Review test-spec.md và test-plan.md
# → Nếu OK thì generate
/ut:generate pref-001
```

### 2. Dùng --review thay vì --force

`--review` giữ lại phần đúng, chỉ fix phần sai.
`--force` tạo lại từ đầu.

### 3. Tạo UT rules sớm

Chạy `/ut:create-rules` ngay khi setup project để AI follow consistent conventions.

### 4. Keep test-spec.md updated

Nếu requirements thay đổi, update `spec.md` và chạy lại `/ut:plan --review`.

### 5. Manual edits are OK

Generated tests là starting point. Feel free to edit, refine, add more assertions.

---

## Quick Reference

```bash
# Setup project (1 lần)
/ut:create-rules

# Workflow chuẩn
/ut:plan pref-001
/ut:generate pref-001

# Workflow nhanh
/ut:auto pref-001

# Review và fix plan
/ut:plan pref-001 --review

# Force overwrite
/ut:plan pref-001 --force
/ut:auto pref-001 --force

# Chỉ plan, không generate
/ut:auto pref-001 --plan-only

# Plan + generate, không run tests
/ut:auto pref-001 --skip-run
```

---

**Version**: 1.0
**Last Updated**: 2025-12-03
