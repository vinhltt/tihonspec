#!/usr/bin/env bash
# =============================================================================
# setup.sh - TihonSpec Installer
# =============================================================================
# Usage: ./setup.sh [OPTIONS]
#
# Installs TihonSpec commands to target project for specified AI providers.
# Supports: Claude Code, GitHub Copilot (Phase 1)
#
# Options:
#   --all              Install all providers
#   --target <path>    Target project directory (default: current directory)
#   -h, --help         Show this help message
# =============================================================================

set -euo pipefail

# =============================================================================
# Color Definitions
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# =============================================================================
# Global Variables
# =============================================================================
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE_DIR="$SCRIPT_DIR/.tihonspec/commands"

# CLI arguments
TARGET_PATH="."
INSTALL_ALL=false
PREFIX=""  # Optional command prefix (e.g., "awz" → awz.feature.*, awz/feature/*)
PROVIDERS=()  # Will be populated by install functions

# =============================================================================
# Logging Functions
# =============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Helper Functions
# =============================================================================

# Print error and exit
die() {
  log_error "$*"
  exit 1
}

# Get absolute path (macOS compatible)
get_abs_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)  # Portable: subshell + pwd
  else
    echo "$path"  # Return as-is if not exists (will create later)
  fi
}

# Create directory if not exists
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || die "Failed to create directory: $dir"
    log_info "Created: $dir"
  fi
}

# Copy file with validation
copy_file() {
  local src="$1"
  local dest="$2"

  [[ -f "$src" ]] || die "Source file not found: $src"

  cp "$src" "$dest" || die "Failed to copy: $src -> $dest"
}

# =============================================================================
# Usage Function
# =============================================================================
show_usage() {
  cat <<EOF
Usage: ./setup.sh [OPTIONS]

TihonSpec Installer - Install AI provider commands to your project.

OPTIONS:
  --all              Install all providers (Claude Code + GitHub Copilot)
  --target <path>    Target project directory (default: current directory)
  --prefix <name>    Add prefix to commands (e.g., "ths" → ths.feature.*, ths/feature/*)
  -h, --help         Show this help message

EXAMPLES:
  ./setup.sh                           # Interactive menu
  ./setup.sh --all                     # Install all to current directory
  ./setup.sh --all --target /my/project
  ./setup.sh --all --prefix ths        # Commands: ths.feature.*, ths/feature/*
  ./setup.sh --target ~/projects/app   # Interactive menu for specific target

EOF
}

# =============================================================================
# Argument Parsing
# =============================================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage
      exit 0
      ;;
    --all)
      INSTALL_ALL=true
      shift
      ;;
    --target)
      [[ -n "${2:-}" ]] || die "--target requires a directory path"
      TARGET_PATH="$2"
      shift 2
      ;;
    --prefix)
      [[ -n "${2:-}" ]] || die "--prefix requires a name"
      PREFIX="$2"
      shift 2
      ;;
    *)
      die "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

# Resolve target to absolute path
TARGET_PATH=$(get_abs_path "$TARGET_PATH")

# =============================================================================
# Validation
# =============================================================================
validate_environment() {
  log_info "Validating environment..."

  # Check source directory exists
  [[ -d "$SOURCE_DIR" ]] || die "Source directory not found: $SOURCE_DIR"

  # Check feature and ut subdirectories
  [[ -d "$SOURCE_DIR/feature" ]] || die "Feature commands not found: $SOURCE_DIR/feature"
  [[ -d "$SOURCE_DIR/ut" ]] || die "UT commands not found: $SOURCE_DIR/ut"

  # Count source files
  local feature_count
  local ut_count
  feature_count=$(find "$SOURCE_DIR/feature" -name "*.md" | wc -l | tr -d ' ')
  ut_count=$(find "$SOURCE_DIR/ut" -name "*.md" | wc -l | tr -d ' ')

  log_info "Found $feature_count feature commands, $ut_count UT commands"
}

# =============================================================================
# Core TihonSpec Installation (Scripts, Templates, Memory)
# =============================================================================

# Copy core .tihonspec folder (scripts, templates, memory)
install_tihonspec_core() {
  log_info "Installing TihonSpec core files..."

  local source_base="$SCRIPT_DIR/.tihonspec"
  local target_base="$TARGET_PATH/.tihonspec"

  # Ensure target directory exists
  ensure_dir "$target_base"

  local count=0

  # Copy scripts folder
  if [[ -d "$source_base/scripts" ]]; then
    log_info "  Copying scripts..."
    cp -r "$source_base/scripts" "$target_base/" || die "Failed to copy scripts"
    local script_count
    script_count=$(find "$target_base/scripts" -type f | wc -l | tr -d ' ')
    log_success "    ✓ scripts/ ($script_count files)"
    count=$((count + script_count))
  fi

  # Copy templates folder
  if [[ -d "$source_base/templates" ]]; then
    log_info "  Copying templates..."
    cp -r "$source_base/templates" "$target_base/" || die "Failed to copy templates"
    local template_count
    template_count=$(find "$target_base/templates" -type f | wc -l | tr -d ' ')
    log_success "    ✓ templates/ ($template_count files)"
    count=$((count + template_count))
  fi

  # Copy memory folder
  if [[ -d "$source_base/memory" ]]; then
    log_info "  Copying memory..."
    cp -r "$source_base/memory" "$target_base/" || die "Failed to copy memory"
    local memory_count
    memory_count=$(find "$target_base/memory" -type f | wc -l | tr -d ' ')
    log_success "    ✓ memory/ ($memory_count files)"
    count=$((count + memory_count))
  fi

  # Copy env template (not the actual .env file)
  if [[ -f "$source_base/.tihonspec.env.example" ]]; then
    log_info "  Copying env template..."
    cp "$source_base/.tihonspec.env.example" "$target_base/" || die "Failed to copy env template"
    log_success "    ✓ .tihonspec.env.example"
    count=$((count + 1))
  fi

  log_success "TihonSpec core: $count files installed"
  echo ""
}

# =============================================================================
# Provider Installation Functions (Phase 2)
# =============================================================================

# Install Claude Code commands (nested subfolder structure)
# With prefix: .claude/commands/{prefix}/feature/*.md
# Without prefix: .claude/commands/feature/*.md
install_claude() {
  local provider="Claude Code"
  log_info "Installing $provider commands..."

  local target_base="$TARGET_PATH/.claude/commands"

  # Add prefix subfolder if specified
  if [[ -n "$PREFIX" ]]; then
    target_base="$target_base/$PREFIX"
    log_info "  Using prefix: $PREFIX"
  fi

  # Ensure base directory
  ensure_dir "$target_base"

  local count=0

  # Install feature commands: feature/*.md → {prefix}/feature/*.md
  log_info "  Installing feature commands..."
  ensure_dir "$target_base/feature"
  for file in "$SOURCE_DIR/feature"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name
    name=$(basename "$file")
    cp "$file" "$target_base/feature/$name" || die "Failed to copy: $file"
    if [[ -n "$PREFIX" ]]; then
      log_success "    ✓ $PREFIX/feature/$name"
    else
      log_success "    ✓ feature/$name"
    fi
    count=$((count + 1))
  done

  # Install UT commands: ut/*.md → {prefix}/ut/*.md
  log_info "  Installing UT commands..."
  ensure_dir "$target_base/ut"
  for file in "$SOURCE_DIR/ut"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name
    name=$(basename "$file")
    cp "$file" "$target_base/ut/$name" || die "Failed to copy: $file"
    if [[ -n "$PREFIX" ]]; then
      log_success "    ✓ $PREFIX/ut/$name"
    else
      log_success "    ✓ ut/$name"
    fi
    count=$((count + 1))
  done

  log_success "$provider: $count files installed"
  echo ""
}

# Install GitHub Copilot commands (flat structure with .prompt suffix)
# With prefix: {prefix}.feature.*.prompt.md, {prefix}.ut.*.prompt.md
# Without prefix: feature.*.prompt.md, ut.*.prompt.md
install_github() {
  local provider="GitHub Copilot"
  log_info "Installing $provider commands..."

  local target_base="$TARGET_PATH/.github/prompts"

  # Log prefix if specified
  if [[ -n "$PREFIX" ]]; then
    log_info "  Using prefix: $PREFIX"
  fi

  # Ensure base directory (flat structure, no subdirs)
  ensure_dir "$target_base"

  local count=0

  # Install feature commands: feature/*.md → {prefix}.feature.*.prompt.md
  log_info "  Installing feature commands..."
  for file in "$SOURCE_DIR/feature"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name
    name=$(basename "$file" .md)
    local dest_name
    if [[ -n "$PREFIX" ]]; then
      dest_name="$PREFIX.feature.$name.prompt.md"
    else
      dest_name="feature.$name.prompt.md"
    fi
    cp "$file" "$target_base/$dest_name" || die "Failed to copy: $file"
    log_success "    ✓ $dest_name"
    count=$((count + 1))
  done

  # Install UT commands: ut/*.md → {prefix}.ut.*.prompt.md (flatten)
  log_info "  Installing UT commands..."
  for file in "$SOURCE_DIR/ut"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name
    name=$(basename "$file" .md)
    local dest_name
    if [[ -n "$PREFIX" ]]; then
      dest_name="$PREFIX.ut.$name.prompt.md"
    else
      dest_name="ut.$name.prompt.md"
    fi
    cp "$file" "$target_base/$dest_name" || die "Failed to copy: $file"
    log_success "    ✓ $dest_name"
    count=$((count + 1))
  done

  log_success "$provider: $count files installed"
  echo ""
}

# Provider router function
install_provider() {
  local provider="$1"

  case "$provider" in
    claude)
      install_claude
      PROVIDERS+=("claude")
      ;;
    github)
      install_github
      PROVIDERS+=("github")
      ;;
    all)
      install_claude
      install_github
      PROVIDERS+=("claude" "github")
      ;;
    *)
      die "Unknown provider: $provider"
      ;;
  esac
}

# =============================================================================
# Manifest Generation (Phase 4)
# =============================================================================

# Generate manifest file with installation metadata
write_manifest() {
  local target="$1"
  local manifest="$target/.tihonspec/.manifest.yaml"

  log_info "Generating manifest file..."

  # Ensure directory exists
  ensure_dir "$(dirname "$manifest")"

  # Get current timestamp (portable)
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

  # Write manifest header
  cat > "$manifest" <<EOF
version: "1.0"
installed_at: "$timestamp"
source_repo: "tihonspec"
EOF

  # Add prefix if specified
  if [[ -n "$PREFIX" ]]; then
    cat >> "$manifest" <<EOF
prefix: "$PREFIX"
EOF
  fi

  cat >> "$manifest" <<EOF
providers:
EOF

  # Append provider entries
  if [[ ${#PROVIDERS[@]} -eq 0 ]]; then
    log_warn "No providers installed. Manifest will be empty."
  else
    for provider in "${PROVIDERS[@]}"; do
      case "$provider" in
        claude)
          cat >> "$manifest" <<EOF
  claude:
    enabled: true
    files_count: 13
EOF
          ;;
        github)
          cat >> "$manifest" <<EOF
  github:
    enabled: true
    files_count: 13
EOF
          ;;
      esac
    done
  fi

  log_success "Manifest created: $manifest"
}

# =============================================================================
# Interactive Menu (Phase 3)
# =============================================================================

# Ask user for installation target path
ask_target_path() {
  echo "Where do you want to install TihonSpec commands?"
  echo ""
  echo "Current path: $TARGET_PATH"
  echo ""
  read -p "Enter target path (press Enter for current path): " user_path

  if [[ -n "$user_path" ]]; then
    TARGET_PATH="$user_path"
    # Resolve to absolute path if directory exists
    TARGET_PATH=$(get_abs_path "$TARGET_PATH")
  fi

  echo ""
  log_info "Target: $TARGET_PATH"
  echo ""
}

# Ask user for optional command prefix
ask_prefix() {
  echo "Do you want to add a prefix to commands? (optional)"
  echo ""
  echo "Examples with prefix 'ths':"
  echo "  Claude:  .claude/commands/ths/feature/*.md"
  echo "  GitHub:  ths.feature.*.prompt.md"
  echo ""
  read -p "Enter prefix (press Enter to skip): " user_prefix

  if [[ -n "$user_prefix" ]]; then
    PREFIX="$user_prefix"
    log_info "Prefix: $PREFIX"
  else
    log_info "No prefix (default)"
  fi
  echo ""
}

# Show interactive provider selection menu
show_interactive_menu() {
  # Target path already asked in main()
  echo "Select AI provider to install:"
  echo ""

  PS3="Enter choice (1-4): "
  select opt in "Claude Code" "GitHub Copilot" "Install All" "Quit"; do
    case $opt in
      "Claude Code")
        echo ""
        install_provider "claude"
        break
        ;;
      "GitHub Copilot")
        echo ""
        install_provider "github"
        break
        ;;
      "Install All")
        echo ""
        install_provider "all"
        break
        ;;
      "Quit")
        log_info "Installation cancelled by user."
        exit 0
        ;;
      *)
        log_warn "Invalid option. Please select 1-4."
        ;;
    esac
  done
}

# =============================================================================
# Self-copy Protection
# =============================================================================

# Check if source and target are the same (prevent self-copy)
check_self_copy() {
  local source_abs
  local target_abs

  source_abs=$(cd "$SCRIPT_DIR" && pwd)
  target_abs=$(get_abs_path "$TARGET_PATH")

  if [[ "$source_abs" == "$target_abs" ]]; then
    die "Cannot install to source directory. Please specify a different --target path."
  fi
}

# =============================================================================
# Main Function
# =============================================================================
main() {
  echo "=============================================="
  echo "  TihonSpec Installer"
  echo "=============================================="
  echo ""

  # In interactive mode, ask for target path and prefix FIRST
  if [[ "$INSTALL_ALL" != "true" ]]; then
    ask_target_path
    ask_prefix
  fi

  log_info "Source: $SOURCE_DIR"
  log_info "Target: $TARGET_PATH"
  echo ""

  # Validate environment and check self-copy
  validate_environment
  check_self_copy

  # Always install TihonSpec core first (scripts, templates, memory)
  echo ""
  install_tihonspec_core

  # Determine installation method for providers
  if [[ "$INSTALL_ALL" == "true" ]]; then
    log_info "Installing all providers (--all flag)..."
    echo ""
    install_provider "all"
  else
    show_interactive_menu
  fi

  # Generate manifest after installation
  write_manifest "$TARGET_PATH"

  echo ""
  echo "=============================================="
  log_success "Installation complete!"
  echo "=============================================="

  # Show summary
  if [[ ${#PROVIDERS[@]} -gt 0 ]]; then
    log_info "Installed providers: ${PROVIDERS[*]}"
    log_info "Target: $TARGET_PATH"
    if [[ -n "$PREFIX" ]]; then
      log_info "Prefix: $PREFIX"
    fi
  fi
}

main "$@"
