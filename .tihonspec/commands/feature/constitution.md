---
description: Create or update the project constitution from interactive or provided principle inputs, ensuring all dependent templates stay in sync
---

## ⛔ CRITICAL: Error Handling

**If ANY script returns an error, you MUST:**
1. **STOP immediately** - Do NOT attempt workarounds or auto-fixes
2. **Report the error** - Show the exact error message to the user
3. **Wait for user** - Ask user how to proceed before taking any action

**DO NOT:**
- Try alternative approaches when scripts fail
- Create branches manually when script validation fails
- Guess or assume what the user wants after an error
- Continue with partial results

---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

You are updating the project constitution at `.tihonspec/memory/constitution.md`. This file is a TEMPLATE containing placeholder tokens in square brackets (e.g. `[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`). Your job is to (a) collect/derive concrete values, (b) fill the template precisely, and (c) propagate any amendments across dependent artifacts.

### Step 0: Validate Task ID

**CRITICAL**: Check task ID argument FIRST before any operations.
**NOTE**: Users must create feature branch manually before running this command.

1. **Parse user input**:
   - Extract first argument from command
   - Expected format: `[folder/]prefix-number`

2. **Check if task ID provided**:
   ```
   If first argument is EMPTY or MISSING:
     ERROR: "Task ID required. Usage: /feature.constitution {task-id}"
     STOP - Do NOT proceed to Step 1
   ```

3. **Validate task ID format**:
   - Must match pattern: `[folder/]{prefix}-number`
   - `{prefix}` = value from `.feature.env` TIHONSPEC_PREFIX_LIST
   - Examples (assuming prefix=pref):
     - ✅ `/feature.constitution {prefix}-001` → e.g., `pref-001`
     - ✅ `/feature.constitution hotfix/{prefix}-123` → e.g., `hotfix/pref-123`
     - ✅ `/feature.constitution AL-991` → if AL in TIHONSPEC_PREFIX_LIST
     - ❌ `/feature.constitution` → ERROR (no task ID)
     - ❌ `/feature.constitution invalid-id` → ERROR (invalid format)

4. **Determine feature directory**:
   - Pattern: `.tihonspec/{folder}/{prefix}-number/`
   - Default folder: `feature` (from TIHONSPEC_DEFAULT_FOLDER)
   - Examples (assuming prefix=pref):
     - `{prefix}-001` → `.tihonspec/feature/pref-001/`
     - `hotfix/{prefix}-123` → `.tihonspec/hotfix/pref-123/`

**Error Handling**:
- If task ID missing → ERROR with usage example, STOP
- If task ID invalid format → ERROR with format requirements, STOP
- If feature directory not found → ERROR, suggest running `/feature.tihonspec` first

**After Validation**:
- Proceed to Step 1 only if task ID valid
- Use task ID to locate feature files in `.tihonspec/{folder}/{task-id}/`

Follow this execution flow:

1. Load the existing constitution template at `.tihonspec/memory/constitution.md`.
   - Identify every placeholder token of the form `[ALL_CAPS_IDENTIFIER]`.
   **IMPORTANT**: The user might require less or more principles than the ones used in the template. If a number is specified, respect that - follow the general template. You will update the doc accordingly.

2. Collect/derive values for placeholders:
   - If user input (conversation) supplies a value, use it.
   - Otherwise infer from existing repo context (README, docs, prior constitution versions if embedded).
   - For governance dates: `RATIFICATION_DATE` is the original adoption date (if unknown ask or mark TODO), `LAST_AMENDED_DATE` is today if changes are made, otherwise keep previous.
   - `CONSTITUTION_VERSION` must increment according to semantic versioning rules:
     - MAJOR: Backward incompatible governance/principle removals or redefinitions.
     - MINOR: New principle/section added or materially expanded guidance.
     - PATCH: Clarifications, wording, typo fixes, non-semantic refinements.
   - If version bump type ambiguous, propose reasoning before finalizing.

3. Draft the updated constitution content:
   - Replace every placeholder with concrete text (no bracketed tokens left except intentionally retained template slots that the project has chosen not to define yet—explicitly justify any left).
   - Preserve heading hierarchy and comments can be removed once replaced unless they still add clarifying guidance.
   - Ensure each Principle section: succinct name line, paragraph (or bullet list) capturing non‑negotiable rules, explicit rationale if not obvious.
   - Ensure Governance section lists amendment procedure, versioning policy, and compliance review expectations.

4. Consistency propagation checklist (convert prior checklist into active validations):
   - Read `.tihonspec/templates/plan-template.md` and ensure any "Constitution Check" or rules align with updated principles.
   - Read `.tihonspec/templates/spec-template.md` for scope/requirements alignment—update if constitution adds/removes mandatory sections or constraints.
   - Read `.tihonspec/templates/tasks-template.md` and ensure task categorization reflects new or removed principle-driven task types (e.g., observability, versioning, testing discipline).
   - Read each command file in `.tihonspec/templates/commands/*.md` (including this one) to verify no outdated references (agent-specific names like CLAUDE only) remain when generic guidance is required.
   - Read any runtime guidance docs (e.g., `README.md`, `docs/quickstart.md`, or agent-specific guidance files if present). Update references to principles changed.

5. Produce a Sync Impact Report (prepend as an HTML comment at top of the constitution file after update):
   - Version change: old → new
   - List of modified principles (old title → new title if renamed)
   - Added sections
   - Removed sections
   - Templates requiring updates (✅ updated / ⚠ pending) with file paths
   - Follow-up TODOs if any placeholders intentionally deferred.

6. Validation before final output:
   - No remaining unexplained bracket tokens.
   - Version line matches report.
   - Dates ISO format YYYY-MM-DD.
   - Principles are declarative, testable, and free of vague language ("should" → replace with MUST/SHOULD rationale where appropriate).

7. Write the completed constitution back to `.tihonspec/memory/constitution.md` (overwrite).

8. Output a final summary to the user with:
   - New version and bump rationale.
   - Any files flagged for manual follow-up.
   - Suggested commit message (e.g., `docs: amend constitution to vX.Y.Z (principle additions + governance update)`).

Formatting & Style Requirements:

- Use Markdown headings exactly as in the template (do not demote/promote levels).
- Wrap long rationale lines to keep readability (<100 chars ideally) but do not hard enforce with awkward breaks.
- Keep a single blank line between sections.
- Avoid trailing whitespace.

If the user supplies partial updates (e.g., only one principle revision), still perform validation and version decision steps.

If critical info missing (e.g., ratification date truly unknown), insert `TODO(<FIELD_NAME>): explanation` and include in the Sync Impact Report under deferred items.

Do not create a new template; always operate on the existing `.tihonspec/memory/constitution.md` file.
