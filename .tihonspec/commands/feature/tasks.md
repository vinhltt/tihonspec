---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
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
### Step 0: Validate or Infer Task ID

**CRITICAL**: Handle task_id before any operations.

1. **Parse user input**:
   - Extract first argument from `$ARGUMENTS`
   - Expected format: `[folder/]prefix-number`

2. **Check if task_id provided**:

   **If task_id provided and valid** (matches pattern `[folder/]prefix-number`):
   - Convert to lowercase (case-insensitive)
   - → Proceed to Step 1 with this task_id

   **If task_id missing or invalid**:
   - → Proceed to inference (step 3)

3. **Infer from conversation context**:
   - Search this conversation for:
     - Previous `/feature.*` or `/ut.*` command executions with task_id
     - Task_id patterns mentioned (e.g., "pref-001", "MRR-123", "aa-2")
     - Output mentioning "Feature pref-001" or similar

   **If context found** (e.g., "pref-001"):
   - Use **AskUserQuestion** tool to confirm:
     ```json
     {
       "questions": [{
         "question": "No task_id provided. Use detected context 'pref-001'?",
         "header": "Task ID",
         "options": [
           {"label": "Yes, use pref-001", "description": "Proceed with the detected task"},
           {"label": "No, specify another", "description": "I'll provide a different task_id"}
         ],
         "multiSelect": false
       }]
     }
     ```
   - If user selects "Yes" → task_id = inferred value (lowercase), proceed to Step 1
   - If user selects "No" → Show usage, STOP

   **If NO context found**:
   ```
   ❌ Error: task_id is required

   Usage: /feature.tasks <task-id>
   Example: /feature.tasks pref-001

   No previous task context found in this conversation.
   ```
   STOP - Do NOT proceed to Step 1

4. **Validate task_id format**:
   - Must match pattern: `[folder/]prefix-number`
   - Prefix must be in `.tihonspec.env` TIHONSPEC_PREFIX_LIST
   - Examples:
     - ✅ `/feature.tasks pref-001` → task_id: `pref-001`
     - ✅ `/feature.tasks PREF-001` → task_id: `pref-001` (case-insensitive)
     - ✅ `/feature.tasks hotfix/pref-123` → task_id: `hotfix/pref-123`
     - ❌ `/feature.tasks` without context → ERROR (no task ID)

5. **Determine feature directory**:
   - Pattern: `.tihonspec/{folder}/{prefix-number}/`
   - Default folder: `feature` (from TIHONSPEC_DEFAULT_FOLDER)
   - If not found → ERROR, suggest running `/feature.tihonspec` first

**After Validation**:
- Proceed to Step 1 only if task_id valid
- Use task_id to locate feature files

### Step 0.5: Load Project Context (Optional)

1. Run: `bash .tihonspec/scripts/bash/detect-config.sh`
2. Parse JSON output into PROJECT_CONTEXT
3. **If PROJECT_CONTEXT.CONFIG_FOUND is true**:
   - Store PROJECT_NAME, PROJECT_PATH, METADATA for context
   - Read each file in RULES_FILES array
   - Apply INLINE_RULES to generation guidelines
   - Use METADATA (language, framework) for tech-specific guidance
4. **If PROJECT_CONTEXT.CONFIG_FOUND is false**: Continue with defaults (backward compatible)
5. **If rules file not found**: Warning "Rule file not found: {path}", continue

**Project Context** (use in later steps):
- Project: {PROJECT_NAME}
- Language: {METADATA.language}
- Framework: {METADATA.framework}
- Rules: Applied from RULES_FILES and INLINE_RULES

### Step 1: Setup

Run `.tihonspec/scripts/bash/check-prerequisites.sh {task_id} --json` from repo root (pass the validated task_id from Step 0). Parse JSON for TASK_ID, FEATURE_DIR, AVAILABLE_DOCS.

2. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
   - Note: Not all projects have all documents. Generate tasks based on what's available.

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories
   - If contracts/ exists: Map endpoints to user stories
   - If research.md exists: Extract decisions for setup tasks
   - Generate tasks organized by user story (see Task Generation Rules below)
   - Generate dependency graph showing user story completion order
   - Create parallel execution examples per user story
   - Validate task completeness (each user story has all needed tasks, independently testable)

4. **Generate tasks.md**: Use `.tihonspec/templates/tasks-template.md` as structure, fill with:
   - Correct feature name from plan.md
   - Phase 1: Setup tasks (project initialization)
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)
   - Phase 3+: One phase per user story (in priority order from spec.md)
   - Each phase includes: story goal, independent test criteria, tests (if requested), implementation tasks
   - Final Phase: Polish & cross-cutting concerns
   - All tasks must follow the strict checklist format (see Task Generation Rules below)
   - Clear file paths for each task
   - Dependencies section showing story completion order
   - Parallel execution examples per story
   - Implementation strategy section (MVP first, incremental delivery)

5. **Report**: Output path to generated tasks.md and summary:
   - Total task count
   - Task count per user story
   - Parallel opportunities identified
   - Independent test criteria for each story
   - Suggested MVP scope (typically just User Story 1)
   - Format validation: Confirm ALL tasks follow the checklist format (checkbox, ID, labels, file paths)

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach.

### Checklist Format (REQUIRED)

Every task MUST strictly follow this format:

```text
- [ ] [TaskID] [P?] [Story?] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **[P] marker**: Include ONLY if task is parallelizable (different files, no dependencies on incomplete tasks)
4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc. (maps to user stories from spec.md)
   - Setup phase: NO story label
   - Foundational phase: NO story label  
   - User Story phases: MUST have story label
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:

- ✅ CORRECT: `- [ ] T001 Create project structure per implementation plan`
- ✅ CORRECT: `- [ ] T005 [P] Implement authentication middleware in src/middleware/auth.py`
- ✅ CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- ✅ CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- ❌ WRONG: `- [ ] Create User model` (missing ID and Story label)
- ❌ WRONG: `T001 [US1] Create model` (missing checkbox)
- ❌ WRONG: `- [ ] [US1] Create User model` (missing Task ID)
- ❌ WRONG: `- [ ] T001 [US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Endpoints/UI needed for that story
     - If tests requested: Tests specific to that story
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
   - Map each contract/endpoint → to the user story it serves
   - If tests requested: Each contract → contract test task [P] before implementation in that story's phase

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships → service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure → Setup phase (Phase 1)
   - Foundational/blocking tasks → Foundational phase (Phase 2)
   - Story-specific setup → within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns
