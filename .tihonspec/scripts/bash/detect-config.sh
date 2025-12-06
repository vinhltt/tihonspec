#!/usr/bin/env bash
# TihonSpec Configuration Discovery
# Finds nearest workspace config (hierarchical model - everything is a workspace)
# Supports --project flag for multi-project workspace targeting

set -euo pipefail

# Maximum directory levels to search upward
readonly MAX_SEARCH_DEPTH=20

# Store workspace root when found
WORKSPACE_ROOT=""

# Target project (from --project flag or auto-detected)
TARGET_PROJECT_NAME=""

# Check prerequisites
check_prerequisites() {
    if ! command -v yq &>/dev/null; then
        echo "ERROR: yq is required but not installed" >&2
        echo "Install with:" >&2
        echo "  macOS:   brew install yq" >&2
        echo "  Linux:   wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && chmod +x /usr/local/bin/yq" >&2
        echo "  Windows: choco install yq" >&2
        exit 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required but not installed" >&2
        echo "Install with:" >&2
        echo "  macOS:   brew install jq" >&2
        echo "  Linux:   apt-get install jq" >&2
        echo "  Windows: choco install jq" >&2
        exit 1
    fi
}

# Find nearest config file (hierarchical model - stop at first found)
# Returns: Single config file path (nearest workspace)
find_config_file() {
    local current_dir="$PWD"
    local depth=0

    while [[ "$current_dir" != "/" ]] && [[ $depth -lt $MAX_SEARCH_DEPTH ]]; do
        local config_file="$current_dir/.tihonspec/.tihonspec.yaml"

        if [[ -f "$config_file" ]]; then
            # Found! Set workspace root and return config path
            WORKSPACE_ROOT="$current_dir"
            echo "$config_file"
            return 0
        fi

        # Move up one directory
        current_dir="$(dirname "$current_dir")"
        ((depth++)) || true
    done

    # No config found
    return 1
}

# Parse single config file to JSON
# Args: config_file
parse_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "{}"
        return
    fi

    # Try to parse YAML
    local yaml_content
    if ! yaml_content=$(yq eval -o=json "$config_file" 2>&1); then
        echo "WARNING: Invalid YAML in $config_file: $yaml_content" >&2
        echo "{}"
        return
    fi

    echo "$yaml_content"
}

# Find project by name in PROJECTS array
# Args: parsed_config, project_name
# Returns: JSON object with project info or empty
find_project_by_name() {
    local parsed="$1"
    local project_name="$2"

    echo "$parsed" | jq -r --arg name "$project_name" '
        .projects // [] | map(select(.name == $name)) | .[0] // empty
    '
}

# Auto-detect project from CWD
# Args: parsed_config
# Returns: project name if CWD is inside a project path
auto_detect_project() {
    local parsed="$1"
    local cwd="$PWD"

    # Get projects array
    local projects
    projects=$(echo "$parsed" | jq -c '.projects // []')

    if [[ "$projects" == "[]" ]] || [[ "$projects" == "null" ]]; then
        return
    fi

    # Check each project path
    echo "$projects" | jq -r '.[] | "\(.name)|\(.path)"' | while IFS='|' read -r name path; do
        local project_full_path="$WORKSPACE_ROOT/$path"
        # Check if CWD starts with project path
        if [[ "$cwd" == "$project_full_path"* ]]; then
            echo "$name"
            return
        fi
    done
}

# Format final JSON output
# Args: parsed_config
output_json() {
    local parsed="$1"

    # Check if config was found
    if [[ "$parsed" == "{}" ]] || [[ -z "$WORKSPACE_ROOT" ]]; then
        echo '{"CONFIG_FOUND": false}'
        return
    fi

    # Build base output JSON with workspace root
    local output
    output=$(echo "$parsed" | jq --arg root "$WORKSPACE_ROOT" '{
        WORKSPACE_ROOT: $root,
        WORKSPACE_NAME: .name,
        DOCS_PATH: (.docs.path // "ai_docs"),
        DOCS_SYNC_BACKUP: (.docs.sync.backup // true),
        DOCS_SYNC_EXCLUDE: (.docs.sync.exclude // []),
        RULES_FILES: (.docs.rules // []),
        INLINE_RULES: (.rules // []),
        PROJECTS: (.projects // []),
        METADATA: (.metadata // {}),
        COMMANDS: (.commands // {}),
        CONFIG_FOUND: true
    }')

    # Handle project targeting
    if [[ -n "$TARGET_PROJECT_NAME" ]]; then
        local project_info
        project_info=$(find_project_by_name "$parsed" "$TARGET_PROJECT_NAME")

        if [[ -z "$project_info" ]]; then
            # Project not found - return error with available projects
            local available
            available=$(echo "$parsed" | jq -c '[.projects // [] | .[].name]')
            echo "$output" | jq --arg req "$TARGET_PROJECT_NAME" --argjson avail "$available" \
                '. + {TARGET_PROJECT: null, ERROR: "project_not_found", REQUESTED_PROJECT: $req, AVAILABLE_PROJECTS: $avail}'
            return
        fi

        # Project found - add TARGET_PROJECT info
        local project_path project_root project_docs_path
        project_path=$(echo "$project_info" | jq -r '.path')
        project_root="$WORKSPACE_ROOT/$project_path"
        # Use project's docs.path if specified, else inherit from workspace
        project_docs_path=$(echo "$project_info" | jq -r '.docs.path // empty')
        if [[ -z "$project_docs_path" ]]; then
            project_docs_path=$(echo "$output" | jq -r '.DOCS_PATH')
        fi

        output=$(echo "$output" | jq \
            --arg name "$TARGET_PROJECT_NAME" \
            --arg path "$project_path" \
            --arg root "$project_root" \
            --arg docs "$project_docs_path" \
            '. + {TARGET_PROJECT: {name: $name, path: $path, root: $root, docs_path: $docs}}')
    fi

    echo "$output"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project)
                if [[ -n "${2:-}" ]]; then
                    TARGET_PROJECT_NAME="$2"
                    shift 2
                else
                    echo '{"CONFIG_FOUND": false, "ERROR": "missing_project_name"}' >&2
                    exit 1
                fi
                ;;
            --help|-h)
                echo "Usage: detect-config.sh [--project NAME]"
                echo ""
                echo "Options:"
                echo "  --project NAME    Target specific project in multi-project workspace"
                echo ""
                echo "Output: JSON with workspace config and optional TARGET_PROJECT info"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Main execution
main() {
    # Parse arguments first
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Find nearest config file (hierarchical model)
    local config_file
    if ! config_file=$(find_config_file); then
        # No config found
        echo '{"CONFIG_FOUND": false}'
        return
    fi

    # Set WORKSPACE_ROOT from config file path (fix subshell issue)
    WORKSPACE_ROOT="$(dirname "$(dirname "$config_file")")"

    # Parse config
    local parsed
    parsed=$(parse_config "$config_file")

    # Auto-detect project from CWD if not specified
    if [[ -z "$TARGET_PROJECT_NAME" ]]; then
        local detected
        detected=$(auto_detect_project "$parsed")
        if [[ -n "$detected" ]]; then
            TARGET_PROJECT_NAME="$detected"
        fi
    fi

    # Output JSON
    output_json "$parsed"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
