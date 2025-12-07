#!/usr/bin/env bash
# TihonSpec Configuration Discovery
# Finds nearest workspace config (hierarchical model - everything is a workspace)
# Supports --sub-workspace flag for multi-sub-workspace workspace targeting

set -euo pipefail

# Maximum directory levels to search upward
readonly MAX_SEARCH_DEPTH=20

# Store workspace root when found
WORKSPACE_ROOT=""

# Target sub-workspace (from --sub-workspace flag or auto-detected)
TARGET_SUB_WORKSPACE_NAME=""

# Check prerequisites and offer to install missing tools
check_prerequisites() {
    local missing_tools=()

    if ! command -v yq &>/dev/null; then
        missing_tools+=("yq")
    fi

    if ! command -v jq &>/dev/null; then
        missing_tools+=("jq")
    fi

    # All tools present
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        return 0
    fi

    # Show missing tools
    echo "ERROR: Required tools not installed: ${missing_tools[*]}" >&2
    echo "" >&2

    # Detect OS and show appropriate install command
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            # Windows (Git Bash/MSYS2)
            echo "To install on Windows, choose one option:" >&2
            echo "" >&2
            echo "  Option 1: Run as Administrator and execute:" >&2
            echo "    choco install ${missing_tools[*]} -y" >&2
            echo "" >&2
            echo "  Option 2: Install manually from:" >&2
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    jq) echo "    - jq: https://jqlang.github.io/jq/download/" >&2 ;;
                    yq) echo "    - yq: https://github.com/mikefarah/yq/releases" >&2 ;;
                esac
            done
            ;;
        Darwin*)
            # macOS
            echo "Install with Homebrew:" >&2
            echo "  brew install ${missing_tools[*]}" >&2
            ;;
        Linux*)
            # Linux
            echo "Install with:" >&2
            for tool in "${missing_tools[@]}"; do
                case "$tool" in
                    jq) echo "  - jq: sudo apt-get install jq  (or yum/dnf)" >&2 ;;
                    yq) echo "  - yq: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq" >&2 ;;
                esac
            done
            ;;
        *)
            echo "Please install: ${missing_tools[*]}" >&2
            ;;
    esac

    echo "" >&2
    exit 1
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

# Find sub-workspace by name in SUB_WORKSPACES array
# Args: parsed_config, sub_workspace_name
# Returns: JSON object with sub-workspace info or empty
find_sub_workspace_by_name() {
    local parsed="$1"
    local sub_workspace_name="$2"

    echo "$parsed" | jq -r --arg name "$sub_workspace_name" '
        .["sub-workspaces"] // [] | map(select(.name == $name)) | .[0] // empty
    '
}

# Auto-detect sub-workspace from CWD
# Args: parsed_config
# Returns: sub-workspace name if CWD is inside a sub-workspace path
auto_detect_sub_workspace() {
    local parsed="$1"
    local cwd="$PWD"

    # Get sub-workspaces array
    local sub_workspaces
    sub_workspaces=$(echo "$parsed" | jq -c '.["sub-workspaces"] // []')

    if [[ "$sub_workspaces" == "[]" ]] || [[ "$sub_workspaces" == "null" ]]; then
        return
    fi

    # Check each sub-workspace path
    echo "$sub_workspaces" | jq -r '.[] | "\(.name)|\(.path)"' | while IFS='|' read -r name path; do
        local sub_workspace_full_path="$WORKSPACE_ROOT/$path"
        # Check if CWD starts with sub-workspace path
        if [[ "$cwd" == "$sub_workspace_full_path"* ]]; then
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
        SUB_WORKSPACES: (.["sub-workspaces"] // []),
        METADATA: (.metadata // {}),
        COMMANDS: (.commands // {}),
        CONFIG_FOUND: true
    }')

    # Handle sub-workspace targeting
    if [[ -n "$TARGET_SUB_WORKSPACE_NAME" ]]; then
        local sub_workspace_info
        sub_workspace_info=$(find_sub_workspace_by_name "$parsed" "$TARGET_SUB_WORKSPACE_NAME")

        if [[ -z "$sub_workspace_info" ]]; then
            # Sub-workspace not found - return error with available sub-workspaces
            local available
            available=$(echo "$parsed" | jq -c '[.["sub-workspaces"] // [] | .[].name]')
            echo "$output" | jq --arg req "$TARGET_SUB_WORKSPACE_NAME" --argjson avail "$available" \
                '. + {TARGET_SUB_WORKSPACE: null, ERROR: "sub_workspace_not_found", REQUESTED_SUB_WORKSPACE: $req, AVAILABLE_SUB_WORKSPACES: $avail}'
            return
        fi

        # Sub-workspace found - add TARGET_SUB_WORKSPACE info
        local sub_workspace_path sub_workspace_root sub_workspace_docs_path
        sub_workspace_path=$(echo "$sub_workspace_info" | jq -r '.path')
        sub_workspace_root="$WORKSPACE_ROOT/$sub_workspace_path"
        # Use sub-workspace's docs.path if specified, else inherit from workspace
        sub_workspace_docs_path=$(echo "$sub_workspace_info" | jq -r '.docs.path // empty')
        if [[ -z "$sub_workspace_docs_path" ]]; then
            sub_workspace_docs_path=$(echo "$output" | jq -r '.DOCS_PATH')
        fi

        output=$(echo "$output" | jq \
            --arg name "$TARGET_SUB_WORKSPACE_NAME" \
            --arg path "$sub_workspace_path" \
            --arg root "$sub_workspace_root" \
            --arg docs "$sub_workspace_docs_path" \
            '. + {TARGET_SUB_WORKSPACE: {name: $name, path: $path, root: $root, docs_path: $docs}}')
    fi

    echo "$output"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sub-workspace)
                if [[ -n "${2:-}" ]]; then
                    TARGET_SUB_WORKSPACE_NAME="$2"
                    shift 2
                else
                    echo '{"CONFIG_FOUND": false, "ERROR": "missing_sub_workspace_name"}' >&2
                    exit 1
                fi
                ;;
            --help|-h)
                echo "Usage: detect-config.sh [--sub-workspace NAME]"
                echo ""
                echo "Options:"
                echo "  --sub-workspace NAME    Target specific sub-workspace in workspace"
                echo ""
                echo "Output: JSON with workspace config and optional TARGET_SUB_WORKSPACE info"
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

    # Auto-detect sub-workspace from CWD if not specified
    if [[ -z "$TARGET_SUB_WORKSPACE_NAME" ]]; then
        local detected
        detected=$(auto_detect_sub_workspace "$parsed")
        if [[ -n "$detected" ]]; then
            TARGET_SUB_WORKSPACE_NAME="$detected"
        fi
    fi

    # Output JSON
    output_json "$parsed"
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
