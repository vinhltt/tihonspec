#!/usr/bin/env bash
# =============================================================================
# sync-commands.sh - Sync commands from source to all platforms
# =============================================================================
# Usage: bash .tihonspec/scripts/bash/sync-commands.sh [--dry-run]
#
# Source: .tihonspec/commands/
# Targets:
#   - .claude/commands/           (feature.*.md, ut/*.md)
#   - .github/prompts/            (feature.*.prompt.md, ut.*.prompt.md)
#   - .gemini/commands/           (feature.*.toml - converted)
#   - .opencode/command/          (feature.*.md)
# =============================================================================

# set -eo pipefail  # Disabled for debugging

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SOURCE_DIR="$REPO_ROOT/.tihonspec/commands"
CLAUDE_DIR="$REPO_ROOT/.claude/commands"
GITHUB_DIR="$REPO_ROOT/.github/prompts"
GEMINI_DIR="$REPO_ROOT/.gemini/commands"
OPENCODE_DIR="$REPO_ROOT/.opencode/command"

# Flags
DRY_RUN=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Create directory if not exists
ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      log_info "[DRY-RUN] Would create: $dir"
    else
      mkdir -p "$dir"
      log_info "Created: $dir"
    fi
  fi
}

# Copy file with optional transformation
copy_file() {
  local src="$1"
  local dest="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would copy: $src -> $dest"
  else
    cp "$src" "$dest"
    [[ "$VERBOSE" == "true" ]] && log_success "Copied: $dest"
  fi
}

# Extract description from markdown file
# Looks for the main command header (e.g., "# /feature.plan - Description")
extract_description() {
  local file="$1"
  local name
  name=$(basename "$file" .md)

  # Try to find line with command pattern and extract description after dash
  local desc
  desc=$(grep -E "^#.*/.*$name" "$file" 2>/dev/null | head -1 | sed 's/^.*- *//' | sed 's/[[:space:]]*$//' || true)

  if [[ -z "$desc" || "$desc" == "#"* ]]; then
    # Fallback: use filename as description
    desc="Execute $name command"
  fi

  echo "$desc"
}

# Convert markdown to Gemini TOML format
convert_to_toml() {
  local src="$1"
  local dest="$2"
  local description

  description=$(extract_description "$src")

  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY-RUN] Would convert: $src -> $dest"
    return
  fi

  # Create TOML file
  {
    echo "description = \"$description\""
    echo ""
    echo "prompt = \"\"\""
    echo "---"
    echo "description: $description"
    echo "---"
    echo ""
    cat "$src"
    echo "\"\"\""
  } > "$dest"

  [[ "$VERBOSE" == "true" ]] && log_success "Converted: $dest"
}

# =============================================================================
# Main sync functions
# =============================================================================

sync_feature_commands() {
  log_info "Syncing TihonSpec commands..."

  local source_feature="$SOURCE_DIR/feature"

  if [[ ! -d "$source_feature" ]]; then
    log_error "Source directory not found: $source_feature"
    return 1
  fi

  # Ensure target directories exist
  ensure_dir "$CLAUDE_DIR"
  ensure_dir "$GITHUB_DIR"
  ensure_dir "$GEMINI_DIR"
  ensure_dir "$OPENCODE_DIR"

  local count=0
  for file in "$source_feature"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name=$(basename "$file" .md)

    # Claude: feature.{name}.md
    copy_file "$file" "$CLAUDE_DIR/feature.$name.md"

    # GitHub Copilot: feature.{name}.prompt.md
    copy_file "$file" "$GITHUB_DIR/feature.$name.prompt.md"

    # OpenCode: feature.{name}.md
    copy_file "$file" "$OPENCODE_DIR/feature.$name.md"

    # Gemini: feature.{name}.toml (converted)
    # Skip status command for Gemini (not supported)
    if [[ "$name" != "status" ]]; then
      convert_to_toml "$file" "$GEMINI_DIR/feature.$name.toml"
    fi

    count=$((count + 1))
  done

  log_success "TihonSpec: $count commands synced"
}

sync_ut_commands() {
  log_info "Syncing UT commands..."

  local source_ut="$SOURCE_DIR/ut"

  if [[ ! -d "$source_ut" ]]; then
    log_error "Source directory not found: $source_ut"
    return 1
  fi

  # Ensure target directories exist
  ensure_dir "$CLAUDE_DIR/ut"
  ensure_dir "$GITHUB_DIR"
  # Note: Gemini and OpenCode don't have UT commands

  local count=0
  for file in "$source_ut"/*.md; do
    [[ ! -f "$file" ]] && continue

    local name=$(basename "$file" .md)

    # Claude: ut/{name}.md
    copy_file "$file" "$CLAUDE_DIR/ut/$name.md"

    # GitHub Copilot: ut.{name}.prompt.md
    copy_file "$file" "$GITHUB_DIR/ut.$name.prompt.md"

    count=$((count + 1))
  done

  log_success "UT: $count commands synced"
}

# =============================================================================
# Main execution
# =============================================================================

main() {
  echo "=============================================="
  echo "  Command Sync Script"
  echo "=============================================="
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "Running in DRY-RUN mode (no changes will be made)"
    echo ""
  fi

  log_info "Source: $SOURCE_DIR"
  log_info "Targets: Claude, GitHub Copilot, Gemini, OpenCode"
  echo ""

  # Check source exists
  if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory not found: $SOURCE_DIR"
    exit 1
  fi

  # Sync commands
  sync_feature_commands
  sync_ut_commands

  echo ""
  echo "=============================================="
  log_success "All commands synced successfully!"
  echo "=============================================="

  # Summary
  echo ""
  echo "Synced to:"
  echo "  - $CLAUDE_DIR/"
  echo "  - $GITHUB_DIR/"
  echo "  - $GEMINI_DIR/"
  echo "  - $OPENCODE_DIR/"
}

main "$@"
