#!/usr/bin/env bash
# =============================================================================
# install.sh - TihonSpec Remote Installer
# =============================================================================
# Usage: curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash
#
# Installs TihonSpec directly from GitHub without cloning the repository.
# Supports: Claude Code, GitHub Copilot
#
# Options:
#   --all              Install all providers
#   --target <path>    Target project directory (default: current directory)
#   --prefix <name>    Add prefix to commands (e.g., "ths" → ths.feature.*)
#   --config-only      Config-only mode: create config, skip commands/scripts
#   --version <tag>    Install specific version (e.g., v1.0.0)
#   --check-update     Check for updates without installing
#   --force            Force reinstall even if up-to-date
#   -h, --help         Show this help message
#
# Examples:
#   curl -fsSL .../install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- --all
#   curl -fsSL .../install.sh | bash -s -- --all --target /my/project
#   curl -fsSL .../install.sh | bash -s -- --version v1.0.0
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
REPO_OWNER="vinhltt"
REPO_NAME="tihonspec"
REPO_BASE_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME"
REPO_ZIP_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs"

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
TEMP_DIR=""
TARGET_PATH="."
INSTALL_ALL=false
CONFIG_ONLY=false
PREFIX=""
VERSION=""           # Specific version to install
CHECK_ONLY=false     # Only check for updates
FORCE=false          # Force reinstall
PROVIDERS=()

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

die() {
  log_error "$*"
  exit 1
}

get_abs_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" && pwd)
  else
    echo "$path"
  fi
}

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir" || die "Failed to create directory: $dir"
  fi
}

# =============================================================================
# HTTP Client Abstraction
# =============================================================================

detect_http_client() {
  if command -v curl &>/dev/null; then
    echo "curl"
  elif command -v wget &>/dev/null; then
    echo "wget"
  else
    die "Neither curl nor wget found. Please install one of them."
  fi
}

fetch_url() {
  local url="$1"
  local client
  client=$(detect_http_client)

  if [[ "$client" == "curl" ]]; then
    curl -fsSL "$url"
  else
    wget -qO- "$url"
  fi
}

download_file() {
  local url="$1"
  local dest="$2"
  local client
  client=$(detect_http_client)

  ensure_dir "$(dirname "$dest")"

  if [[ "$client" == "curl" ]]; then
    curl -fsSL -o "$dest" "$url"
  else
    wget -q -O "$dest" "$url"
  fi
}

# =============================================================================
# Version Management
# =============================================================================

# Compare semantic versions
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
version_compare() {
  local v1="${1#v}" v2="${2#v}"  # Strip 'v' prefix

  if [[ "$v1" == "$v2" ]]; then
    echo 0
    return
  fi

  local IFS=.
  local i arr1=($v1) arr2=($v2)

  for ((i=0; i<3; i++)); do
    local n1=${arr1[i]:-0}
    local n2=${arr2[i]:-0}
    if ((10#$n1 > 10#$n2)); then
      echo 1
      return
    fi
    if ((10#$n1 < 10#$n2)); then
      echo 2
      return
    fi
  done
  echo 0
}

# Get installed version from manifest
get_installed_version() {
  local manifest="$TARGET_PATH/.tihonspec/.manifest.yaml"
  if [[ -f "$manifest" ]]; then
    grep "tihonspec_version:" "$manifest" 2>/dev/null | sed 's/.*"\(.*\)".*/\1/' || echo ""
  else
    echo ""
  fi
}

# Get latest version from remote
get_latest_version() {
  local version_url="$REPO_BASE_URL/main/version.txt"
  fetch_url "$version_url" 2>/dev/null | tr -d '\n' || echo ""
}

# Check for updates
check_updates() {
  local installed="$1"
  local latest="$2"

  if [[ -z "$latest" ]]; then
    log_warn "Could not fetch latest version"
    return 1
  fi

  if [[ -z "$installed" ]]; then
    log_info "Fresh installation"
    return 1  # Proceed with install
  fi

  local cmp
  cmp=$(version_compare "$installed" "$latest")

  case "$cmp" in
    0)
      log_success "Already up-to-date: $installed"
      return 0
      ;;
    1)
      log_success "Local version ($installed) is newer than remote ($latest)"
      return 0
      ;;
    2)
      log_info "Update available: $installed → $latest"
      return 1  # Proceed with install
      ;;
  esac
}

# =============================================================================
# Temporary Directory Management
# =============================================================================

create_temp_dir() {
  TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'tihonspec')
  chmod 700 "$TEMP_DIR"
}

cleanup_temp_dir() {
  if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup_temp_dir EXIT

# =============================================================================
# Download Functions
# =============================================================================

# Download and extract ZIP (fast method)
download_zip() {
  local version="$1"
  local zip_url zip_file extracted_dir

  log_info "Downloading TihonSpec $version..."

  # Construct ZIP URL
  if [[ "$version" == "main" ]] || [[ -z "$version" ]]; then
    zip_url="$REPO_ZIP_URL/heads/main.zip"
    version="main"
  else
    zip_url="$REPO_ZIP_URL/tags/$version.zip"
  fi

  zip_file="$TEMP_DIR/tihonspec.zip"

  # Download ZIP
  download_file "$zip_url" "$zip_file" || die "Failed to download: $zip_url"

  # Extract ZIP
  log_info "Extracting..."
  unzip -q "$zip_file" -d "$TEMP_DIR" || die "Failed to extract ZIP"

  # Find extracted folder (tihonspec-main or tihonspec-v1.0.0)
  extracted_dir=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "$REPO_NAME-*" | head -1)

  if [[ -z "$extracted_dir" ]] || [[ ! -d "$extracted_dir" ]]; then
    die "Could not find extracted directory"
  fi

  # Move .tihonspec to expected location
  if [[ -d "$extracted_dir/.tihonspec" ]]; then
    mv "$extracted_dir/.tihonspec" "$TEMP_DIR/.tihonspec"
  else
    die ".tihonspec directory not found in archive"
  fi

  log_success "Downloaded $version"
}

# Download files individually (fallback method)
download_files() {
  log_info "Downloading files (fallback mode)..."

  local manifest_url="$REPO_BASE_URL/main/files.txt"
  local manifest_content

  manifest_content=$(fetch_url "$manifest_url") || die "Failed to download manifest"

  local total=0 count=0

  total=$(echo "$manifest_content" | grep -v '^#' | grep -v '^$' | wc -l | tr -d ' ')

  log_info "Found $total files to download"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" =~ ^# ]] && continue

    count=$((count + 1))
    local url="$REPO_BASE_URL/main/$file"
    local dest="$TEMP_DIR/$file"

    printf "\r  [%d/%d] Downloading..." "$count" "$total"

    download_file "$url" "$dest" || die "Failed to download: $file"
  done <<< "$manifest_content"

  printf "\r"
  log_success "Downloaded $count files"
}

# =============================================================================
# Installation Functions
# =============================================================================

install_tihonspec_core() {
  log_info "Installing TihonSpec core files..."

  local source_base="$TEMP_DIR/.tihonspec"
  local target_base="$TARGET_PATH/.tihonspec"

  ensure_dir "$target_base"

  local count=0

  # Copy folders
  for folder in scripts templates memory docs examples; do
    if [[ -d "$source_base/$folder" ]]; then
      cp -r "$source_base/$folder" "$target_base/" || die "Failed to copy $folder"
      local folder_count
      folder_count=$(find "$target_base/$folder" -type f | wc -l | tr -d ' ')
      log_success "  ✓ $folder/ ($folder_count files)"
      count=$((count + folder_count))
    fi
  done

  # Copy individual files
  for file in .tihonspec.env.example tihonspec.yaml.template; do
    if [[ -f "$source_base/$file" ]]; then
      cp "$source_base/$file" "$target_base/" || die "Failed to copy $file"
      log_success "  ✓ $file"
      count=$((count + 1))
    fi
  done

  log_success "TihonSpec core: $count files installed"
  echo ""
}

generate_tihonspec_config() {
  local target="$1"
  local config_type="$2"
  local project_name="$3"

  local config_file="$target/.tihonspec/.tihonspec.yaml"
  local template_file="$TEMP_DIR/.tihonspec/tihonspec.yaml.template"

  if [[ -f "$config_file" ]]; then
    log_info "Config exists, skipping: $config_file"
    return 0
  fi

  ensure_dir "$(dirname "$config_file")"

  if [[ -f "$template_file" ]]; then
    cp "$template_file" "$config_file"
    if command -v sed &>/dev/null; then
      sed -i.bak "s/^name: .*/name: \"$project_name\"/" "$config_file"
      sed -i.bak "s/^type: .*/type: \"$config_type\"/" "$config_file"
      rm -f "$config_file.bak"
    fi
    log_success "Created config: $config_file"
  else
    if [[ "$config_type" == "workspace" ]]; then
      cat > "$config_file" <<EOF
version: "1.0"
name: "$project_name"
type: "workspace"

docs:
  path: "ai_docs"
  rules: []

rules: []
commands: {}
projects: []
EOF
    else
      cat > "$config_file" <<EOF
version: "1.0"
name: "$project_name"
type: "project"

docs:
  path: "ai_docs"
  rules: []

metadata:
  language: ""
  framework: ""
  package_manager: ""
  test_framework: ""

rules: []
commands:
  test: ""
  build: ""
  lint: ""
EOF
    fi
    log_success "Created config: $config_file"
  fi
}

install_claude() {
  local provider="Claude Code"
  log_info "Installing $provider commands..."

  local source_base="$TEMP_DIR/.tihonspec/commands"
  local target_base="$TARGET_PATH/.claude/commands"

  if [[ -n "$PREFIX" ]]; then
    target_base="$target_base/$PREFIX"
    log_info "  Using prefix: $PREFIX"
  fi

  ensure_dir "$target_base"

  local count=0

  for folder in feature ut project; do
    if [[ -d "$source_base/$folder" ]]; then
      ensure_dir "$target_base/$folder"
      local folder_count=0
      for file in "$source_base/$folder"/*.md; do
        [[ ! -f "$file" ]] && continue
        local name
        name=$(basename "$file")
        cp "$file" "$target_base/$folder/$name" || die "Failed to copy: $file"
        folder_count=$((folder_count + 1))
      done
      if [[ $folder_count -gt 0 ]]; then
        log_success "  ✓ $folder/ ($folder_count files)"
        count=$((count + folder_count))
      fi
    fi
  done

  log_success "$provider: $count files installed"
  echo ""
}

install_github() {
  local provider="GitHub Copilot"
  log_info "Installing $provider commands..."

  local source_base="$TEMP_DIR/.tihonspec/commands"
  local target_base="$TARGET_PATH/.github/prompts"

  if [[ -n "$PREFIX" ]]; then
    log_info "  Using prefix: $PREFIX"
  fi

  ensure_dir "$target_base"

  local count=0

  for folder in feature ut project; do
    if [[ -d "$source_base/$folder" ]]; then
      for file in "$source_base/$folder"/*.md; do
        [[ ! -f "$file" ]] && continue
        local name
        name=$(basename "$file" .md)
        local dest_name
        if [[ -n "$PREFIX" ]]; then
          dest_name="$PREFIX.$folder.$name.prompt.md"
        else
          dest_name="$folder.$name.prompt.md"
        fi
        cp "$file" "$target_base/$dest_name" || die "Failed to copy: $file"
        count=$((count + 1))
      done
    fi
  done

  log_success "$provider: $count files installed"
  echo ""
}

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

write_manifest() {
  local target="$1"
  local version="$2"
  local manifest="$target/.tihonspec/.manifest.yaml"

  log_info "Generating manifest file..."

  ensure_dir "$(dirname "$manifest")"

  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

  cat > "$manifest" <<EOF
version: "1.0"
tihonspec_version: "$version"
installed_at: "$timestamp"
source_repo: "$REPO_NAME"
install_method: "remote"
EOF

  if [[ -n "$PREFIX" ]]; then
    echo "prefix: \"$PREFIX\"" >> "$manifest"
  fi

  echo "providers:" >> "$manifest"

  for provider in "${PROVIDERS[@]}"; do
    echo "  $provider:" >> "$manifest"
    echo "    enabled: true" >> "$manifest"
  done

  log_success "Manifest created: $manifest"
}

# =============================================================================
# Usage Function
# =============================================================================
show_usage() {
  cat <<EOF
Usage: curl -fsSL <url>/install.sh | bash -s -- [OPTIONS]

TihonSpec Remote Installer - Install directly from GitHub.

OPTIONS:
  --all              Install all providers (Claude Code + GitHub Copilot)
  --target <path>    Target project directory (default: current directory)
  --prefix <name>    Add prefix to commands (e.g., "ths" → ths.feature.*)
  --config-only      Config-only mode: create config, skip commands/scripts
  --version <tag>    Install specific version (e.g., v1.0.0, default: latest)
  --check-update     Check for updates without installing
  --force            Force reinstall even if up-to-date
  -h, --help         Show this help message

EXAMPLES:
  curl -fsSL .../install.sh | bash
  curl -fsSL .../install.sh | bash -s -- --all
  curl -fsSL .../install.sh | bash -s -- --all --target /my/project
  curl -fsSL .../install.sh | bash -s -- --version v1.0.0
  curl -fsSL .../install.sh | bash -s -- --check-update

WINDOWS:
  Requires Git Bash or WSL. Run from Git Bash terminal.

EOF
}

# =============================================================================
# Interactive Menu
# =============================================================================
ask_target_path() {
  echo "Where do you want to install TihonSpec commands?"
  echo ""
  echo "Current path: $TARGET_PATH"
  echo ""
  read -p "Enter target path (press Enter for current path): " user_path

  if [[ -n "$user_path" ]]; then
    TARGET_PATH="$user_path"
    TARGET_PATH=$(get_abs_path "$TARGET_PATH")
  fi

  echo ""
  log_info "Target: $TARGET_PATH"
  echo ""
}

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

show_interactive_menu() {
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
    --config-only)
      CONFIG_ONLY=true
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
    --version)
      [[ -n "${2:-}" ]] || die "--version requires a version tag (e.g., v1.0.0)"
      VERSION="$2"
      shift 2
      ;;
    --check-update)
      CHECK_ONLY=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *)
      die "Unknown option: $1. Use --help for usage."
      ;;
  esac
done

TARGET_PATH=$(get_abs_path "$TARGET_PATH")

# =============================================================================
# Main Function
# =============================================================================
main() {
  echo "=============================================="
  echo "  TihonSpec Remote Installer"
  echo "=============================================="
  echo ""

  # Get version info
  local installed_version latest_version install_version

  installed_version=$(get_installed_version)
  latest_version=$(get_latest_version)

  # Determine version to install
  if [[ -n "$VERSION" ]]; then
    install_version="$VERSION"
  elif [[ -n "$latest_version" ]]; then
    install_version="$latest_version"
  else
    install_version="main"
  fi

  # Check-only mode
  if [[ "$CHECK_ONLY" == "true" ]]; then
    echo "Current:  ${installed_version:-not installed}"
    echo "Latest:   ${latest_version:-unknown}"
    echo ""

    if [[ -z "$installed_version" ]]; then
      log_info "TihonSpec is not installed. Run without --check-update to install."
    elif [[ -z "$latest_version" ]]; then
      log_warn "Could not check latest version."
    else
      local cmp
      cmp=$(version_compare "$installed_version" "$latest_version")
      case "$cmp" in
        0) log_success "You are up-to-date!" ;;
        1) log_success "You have a newer version than remote." ;;
        2) log_info "Update available! Run installer to update." ;;
      esac
    fi
    exit 0
  fi

  # Check if update needed (unless --force)
  if [[ "$FORCE" != "true" ]] && [[ -n "$installed_version" ]]; then
    if check_updates "$installed_version" "$install_version"; then
      log_info "Use --force to reinstall"
      exit 0
    fi
  fi

  # Create temp directory
  create_temp_dir

  # Download files (ZIP or fallback)
  if command -v unzip &>/dev/null; then
    download_zip "$install_version"
  else
    log_warn "unzip not found, using fallback method (slower)..."
    download_files
  fi
  echo ""

  # Interactive mode: ask for target and prefix
  if [[ "$INSTALL_ALL" != "true" ]] && [[ "$CONFIG_ONLY" != "true" ]]; then
    ask_target_path
    ask_prefix
  fi

  log_info "Target: $TARGET_PATH"
  echo ""

  # Config-only mode
  if [[ "$CONFIG_ONLY" == "true" ]]; then
    log_info "Config-only mode: Creating config..."
    echo ""

    local project_name
    project_name=$(basename "$TARGET_PATH")

    generate_tihonspec_config "$TARGET_PATH" "project" "$project_name"

    echo ""
    echo "=============================================="
    log_success "Config created!"
    echo "=============================================="
    log_info "Edit .tihonspec/.tihonspec.yaml to configure settings"
    return 0
  fi

  # Full installation
  install_tihonspec_core

  # Generate workspace config
  local workspace_name
  workspace_name=$(basename "$TARGET_PATH")
  generate_tihonspec_config "$TARGET_PATH" "workspace" "$workspace_name"
  echo ""

  # Install providers
  if [[ "$INSTALL_ALL" == "true" ]]; then
    log_info "Installing all providers (--all flag)..."
    echo ""
    install_provider "all"
  else
    show_interactive_menu
  fi

  # Generate manifest with version
  write_manifest "$TARGET_PATH" "$install_version"

  echo ""
  echo "=============================================="
  log_success "Installation complete!"
  echo "=============================================="

  if [[ ${#PROVIDERS[@]} -gt 0 ]]; then
    log_info "Version: $install_version"
    log_info "Providers: ${PROVIDERS[*]}"
    log_info "Target: $TARGET_PATH"
    if [[ -n "$PREFIX" ]]; then
      log_info "Prefix: $PREFIX"
    fi
  fi
}

main "$@"
