#!/usr/bin/env bash
# Environment configuration loader for TihonSpec
# Auto-loaded by all TihonSpec bash scripts

# Find repository root (git-aware with fallback)
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../.." && pwd)
    fi
}

# Load environment configuration with defaults
load_feature_env() {
    local repo_root=$(get_repo_root)

    # Determine which env file to load
    local env_name="${TIHONSPEC_ENV:-default}"
    local env_file="$repo_root/.tihonspec/.feature.env"

    # If TIHONSPEC_ENV is set, try environment-specific file
    if [[ -n "$TIHONSPEC_ENV" ]]; then
        local specific_env="$repo_root/.tihonspec/.feature.env.$TIHONSPEC_ENV"
        if [[ -f "$specific_env" ]]; then
            env_file="$specific_env"
            echo "[feature] Loading environment: $TIHONSPEC_ENV" >&2
        else
            echo "[feature] Warning: $TIHONSPEC_ENV config not found, using default" >&2
        fi
    fi

    # Set defaults (backward compatible - same as hardcoded values)
    export TIHONSPEC_PREFIX_LIST="${TIHONSPEC_PREFIX_LIST:-aa}"
    export TIHONSPEC_DEFAULT_FOLDER="${TIHONSPEC_DEFAULT_FOLDER:-feature}"
    export TIHONSPEC_MAIN_BRANCH="${TIHONSPEC_MAIN_BRANCH:-master}"
    export TIHONSPEC_SPECS_ROOT="${TIHONSPEC_SPECS_ROOT:-.tihonspec}"
    export TIHONSPEC_TICKET_FORMAT="${TIHONSPEC_TICKET_FORMAT:-^([a-zA-Z]+/)?([a-zA-Z]+)-([0-9]+)$}"
    export TIHONSPEC_HOOK_TIMEOUT="${TIHONSPEC_HOOK_TIMEOUT:-30}"
    export TIHONSPEC_HOOK_FAIL_BEHAVIOR="${TIHONSPEC_HOOK_FAIL_BEHAVIOR:-exit}"

    # Load from file if exists
    if [[ -f "$env_file" ]]; then
        echo "[feature] Loading config from: ${env_file#$repo_root/}" >&2

        while IFS= read -r line || [[ -n "$line" ]]; do
            # Remove carriage return (Windows line endings)
            line="${line%$'\r'}"

            # Skip comments and empty lines
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue

            # Export valid TIHONSPEC_* KEY=VALUE lines
            if [[ "$line" =~ ^TIHONSPEC_[A-Z_]+=.* ]]; then
                export "$line"
            fi
        done < "$env_file"
    else
        echo "[feature] No config file found, using defaults" >&2
    fi

    # Display loaded config (for debugging)
    if [[ "${TIHONSPEC_DEBUG:-false}" == "true" ]]; then
        echo "[feature] Configuration:" >&2
        echo "  PREFIX_LIST: $TIHONSPEC_PREFIX_LIST" >&2
        echo "  DEFAULT_FOLDER: $TIHONSPEC_DEFAULT_FOLDER" >&2
        echo "  MAIN_BRANCH: $TIHONSPEC_MAIN_BRANCH" >&2
        echo "  SPECS_ROOT: $TIHONSPEC_SPECS_ROOT" >&2
        echo "  VALIDATION_HOOK: ${TIHONSPEC_VALIDATION_HOOK:-(none)}" >&2
    fi
}

# Validate prefix against allowed list
validate_prefix() {
    local prefix="$1"
    local allowed_prefixes="${TIHONSPEC_PREFIX_LIST//,/ }"

    # Wildcard: allow any prefix
    if [[ "$TIHONSPEC_PREFIX_LIST" == "*" ]]; then
        return 0
    fi

    # Case-insensitive comparison
    local prefix_lower="${prefix,,}"

    for allowed in $allowed_prefixes; do
        local allowed_lower="${allowed,,}"
        if [[ "$prefix_lower" == "$allowed_lower" ]]; then
            return 0
        fi
    done

    echo "ERROR: Invalid prefix '$prefix'" >&2
    echo "Allowed prefixes: $TIHONSPEC_PREFIX_LIST" >&2
    return 1
}

# Parse ticket ID into components
# Input: [folder/]prefix-number
# Output: folder|prefix|number (pipe-separated)
parse_ticket_id() {
    local ticket_id="$1"
    local folder=""
    local prefix=""
    local number=""

    # Match format using configured regex
    if [[ "$ticket_id" =~ $TIHONSPEC_TICKET_FORMAT ]]; then
        # Extract components (regex groups)
        folder="${BASH_REMATCH[1]%/}"  # Remove trailing /
        prefix="${BASH_REMATCH[2]}"
        number="${BASH_REMATCH[3]}"

        # Use default folder if not specified
        if [[ -z "$folder" ]]; then
            folder="$TIHONSPEC_DEFAULT_FOLDER"
        fi

        # Validate prefix against allowed list
        if ! validate_prefix "$prefix"; then
            return 1
        fi

        # Output pipe-separated values
        echo "$folder|$prefix|$number"
        return 0
    else
        echo "ERROR: Invalid ticket ID format: '$ticket_id'" >&2
        echo "Expected format: [folder/]prefix-number" >&2
        echo "Examples: $TIHONSPEC_DEFAULT_FOLDER/aa-123 or aa-456" >&2
        return 1
    fi
}

# Parse feature ID and return folder, ticket, and paths
# Usage: parse_feature_id <feature-id>
# Returns: folder|ticket|feature_dir|branch_name
# Examples:
#   aa-123        → feature|aa-123|.tihonspec/feature/aa-123|feature/aa-123
#   test/aa-123   → test|aa-123|.tihonspec/test/aa-123|test/aa-123
parse_feature_id() {
    local feature_id="$1"
    local folder=""
    local ticket=""
    local feature_dir=""
    local branch_name=""

    # Get repo root
    local repo_root=$(get_repo_root)

    # Parse feature ID
    if [[ "$feature_id" == */* ]]; then
        # Contains folder: test/aa-123 → .tihonspec/test/aa-123
        folder="${feature_id%%/*}"
        ticket="${feature_id#*/}"
    else
        # No folder, use default: aa-123 → .tihonspec/feature/aa-123
        folder="$TIHONSPEC_DEFAULT_FOLDER"
        ticket="$feature_id"
    fi

    # Build paths
    feature_dir="${repo_root}/${TIHONSPEC_SPECS_ROOT}/${folder}/${ticket}"
    branch_name="${folder}/${ticket}"

    # Output pipe-separated values
    echo "${folder}|${ticket}|${feature_dir}|${branch_name}"
    return 0
}

# Run validation hook if configured
# Arguments: prefix, number, folder, [phase]
run_validation_hook() {
    local prefix="$1"
    local number="$2"
    local folder="$3"
    local phase="${4:-create}"

    # Skip if no hook configured
    if [[ -z "$TIHONSPEC_VALIDATION_HOOK" ]]; then
        return 0
    fi

    # Resolve hook path (relative to repo root)
    local repo_root=$(get_repo_root)
    local hook_path="$TIHONSPEC_VALIDATION_HOOK"

    # Make path absolute if relative
    if [[ "$hook_path" != /* ]]; then
        hook_path="$repo_root/$hook_path"
    fi

    # Check hook file exists
    if [[ ! -f "$hook_path" ]]; then
        echo "[feature] Warning: Hook configured but not found: $TIHONSPEC_VALIDATION_HOOK" >&2
        return 0
    fi

    # Export variables for hook script
    export TIHONSPEC_HOOK_PREFIX="$prefix"
    export TIHONSPEC_HOOK_NUMBER="$number"
    export TIHONSPEC_HOOK_FOLDER="$folder"
    export TIHONSPEC_HOOK_PHASE="$phase"
    export TIHONSPEC_HOOK_TICKET_ID="$prefix-$number"

    echo "[feature] Running validation hook: $phase phase" >&2

    # Run hook with timeout
    local timeout="${TIHONSPEC_HOOK_TIMEOUT:-30}"

    if timeout "$timeout" bash "$hook_path"; then
        echo "[feature] ✅ Validation passed" >&2
        return 0
    else
        local exit_code=$?

        # Check if timeout occurred (exit code 124)
        if [[ $exit_code -eq 124 ]]; then
            echo "[feature] ❌ Validation hook timed out after ${timeout}s" >&2
        else
            echo "[feature] ❌ Validation failed (exit code: $exit_code)" >&2
        fi

        # Check fail behavior
        if [[ "${TIHONSPEC_HOOK_FAIL_BEHAVIOR:-exit}" == "warn" ]]; then
            echo "[feature] ⚠️  Continuing despite validation failure (warn mode)" >&2
            return 0
        fi

        return $exit_code
    fi
}

# Auto-load environment on source
load_feature_env
