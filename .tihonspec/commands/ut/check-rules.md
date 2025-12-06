# /ut:check-rules - Validate UT Rules

## Purpose

Check if UT rules (`ut-rule.md`) exist for project/workspace. Shows summary if found.

---

## Usage

```bash
/ut:check-rules                    # Check workspace rules
/ut:check-rules --project {name}   # Check project-specific rules
```

---

## Execution

### Step 0: Parse Arguments & Project Selection

**Parse user input for project targeting**:
1. Check if `--project NAME` in command args
2. Check if user mentions project name in natural language
3. If multi-project workspace and no project specified → Ask user which project

**Run bash script**:

```bash
# If project specified:
bash .tihonspec/scripts/bash/ut/check-rules.sh --project {PROJECT_NAME}

# Otherwise:
bash .tihonspec/scripts/bash/ut/check-rules.sh
```

Parse JSON output → Store `RULES_FILE`, `EXISTS`, `FRAMEWORK`, `COVERAGE_TARGET`

---

### Step 1: Check Result

**If EXISTS = true**:
- Read `RULES_FILE` content
- Display summary:
  ```
  ✅ UT Rules Found
  ==================
  File: {RULES_FILE}
  Framework: {FRAMEWORK}
  Coverage: {COVERAGE_TARGET}

  Key sections:
  - Naming conventions ✓
  - Test organization ✓
  - Mocking strategy ✓
  ```

**If EXISTS = false**:
- Show error:
  ```
  ❌ UT Rules Not Found
  ======================
  Expected: {RULES_FILE}

  💡 Run `/ut:create-rules` to create UT standards first.
  ```
- Exit with suggestion

---

## Output

| Field | Description |
|-------|-------------|
| `RULES_FILE` | Full path to ut-rule.md |
| `EXISTS` | true/false |
| `FRAMEWORK` | Detected framework (vitest, jest, etc.) |
| `COVERAGE_TARGET` | Coverage percentage |

---

## Related

- `ut:create-rules` - Create UT rules
- `ut:plan` - Create test plan (uses rules)
- `ut:generate` - Generate tests (requires rules)
