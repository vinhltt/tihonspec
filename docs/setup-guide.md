# TihonSpec Setup Guide

Hướng dẫn cài đặt TihonSpec cho project mới.

## Quick Start

```bash
# Remote installation (recommended)
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash
```

## Installation Methods

### 1. Remote Installation (Recommended)

Install directly from GitHub without cloning:

```bash
# One-liner (interactive mode)
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash

# Install all providers to specific path
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash -s -- --all --target /path/to/project

# With prefix
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash -s -- --all --prefix ths

# Config-only mode (child projects)
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash -s -- --config-only --target /path/to/project
```

**Using wget (if curl unavailable):**
```bash
wget -qO- https://raw.githubusercontent.com/vinhltt/tihonspec/main/install.sh | bash
```

**Install specific version:**
```bash
# Replace 'main' with tag name (e.g., v1.0.0)
curl -fsSL https://raw.githubusercontent.com/vinhltt/tihonspec/v1.0.0/install.sh | bash
```

### 2. Local Installation

Clone repo and run installer:

```bash
# Clone TihonSpec repo
git clone https://github.com/vinhltt/tihonspec.git
cd tihonspec

# Run installer (interactive mode)
./setup.sh
```

Script sẽ hỏi:
1. **Target path** - Đường dẫn project cần cài đặt
2. **Prefix** (optional) - Prefix cho commands (vd: `ths`)
3. **Provider** - Chọn AI provider

```bash
# Install all providers to specific path
./setup.sh --all --target /path/to/project

# With prefix
./setup.sh --all --target /path/to/project --prefix ths
```

### CLI Options

| Option | Description |
|--------|-------------|
| `--all` | Install all providers (Claude + GitHub Copilot) |
| `--target <path>` | Target project directory (default: current) |
| `--prefix <name>` | Add prefix to commands |
| `--config-only` | Config file only, inherits parent commands |
| `-h, --help` | Show help |

## What Gets Installed

```
your-project/
├── .tihonspec/                    # Core files
│   ├── scripts/bash/              # Automation scripts
│   ├── templates/                 # Markdown templates
│   ├── memory/                    # Constitution file
│   └── .tihonspec.env.example     # Environment template
│
├── .claude/commands/              # Claude Code commands
│   ├── feature/                   # Feature workflow commands
│   │   ├── specify.md
│   │   ├── clarify.md
│   │   ├── plan.md
│   │   └── ...
│   └── ut/                        # Unit test commands
│       ├── auto.md
│       ├── generate.md
│       └── ...
│
└── .github/prompts/               # GitHub Copilot commands
    ├── feature.specify.prompt.md
    ├── feature.clarify.prompt.md
    ├── ut.auto.prompt.md
    └── ...
```

### With Prefix (e.g., `ths`)

```
your-project/
├── .claude/commands/ths/          # Prefixed subfolder
│   ├── feature/*.md
│   └── ut/*.md
│
└── .github/prompts/
    ├── ths.feature.*.prompt.md    # Prefixed filenames
    └── ths.ut.*.prompt.md
```

## Post-Installation

### 1. Configure Workspace (Optional)

Create `.tihonspec/.tihonspec.yaml` for workspace configuration:

```yaml
version: "1.0"
name: "my-project"

docs:
  path: "ai_docs"
```

See [Configuration Guide](./configuration-guide.md) for full reference.

### 2. Configure Environment

```bash
cd your-project/.tihonspec
cp .tihonspec.env.example .tihonspec.env
# Edit .tihonspec.env with your settings
```

### 3. Verify Installation

**Claude Code:**
```bash
# List available commands
ls .claude/commands/feature/
ls .claude/commands/ut/
```

**GitHub Copilot:**
```bash
ls .github/prompts/
```

### 4. Test Commands

**Claude Code:**
```
/feature/specify
/ut/auto
```

**GitHub Copilot:**
- Use `@workspace /feature.specify` in Copilot Chat

## Available Commands

### Feature Workflow

| Command | Description |
|---------|-------------|
| `specify` | Create feature specification |
| `clarify` | Clarify requirements |
| `plan` | Generate implementation plan |
| `tasks` | Break down into tasks |
| `analyze` | Analyze codebase for feature |
| `implement` | Execute implementation |
| `status` | Check implementation status |
| `checklist` | Generate checklist |
| `constitution` | View/update constitution |

### Unit Test Workflow

| Command | Description |
|---------|-------------|
| `auto` | Auto-generate unit tests |
| `generate` | Generate tests from spec |
| `create-rules` | Create test rules |
| `plan` | Plan test strategy |

## Troubleshooting

### Remote Installation Issues

#### Error: "Neither curl nor wget found"
Install curl hoặc wget:
- macOS: `brew install curl`
- Ubuntu/Debian: `sudo apt install curl`

#### Error: "Failed to download files"
Kiểm tra kết nối internet. Nếu dùng proxy:
```bash
export https_proxy=http://proxy:port
curl -fsSL ...
```

#### Network timeout
Files download từ GitHub. Nếu chậm:
1. Thử lại sau
2. Dùng local installation thay thế

### Local Installation Issues

#### Error: "Cannot install to source directory"

Bạn đang chạy setup.sh trong chính thư mục TihonSpec. Cần chỉ định target khác:

```bash
./setup.sh --target /path/to/your/project
```

#### Error: "Source directory not found"

Đảm bảo bạn đang chạy từ thư mục gốc của TihonSpec repo:

```bash
cd /path/to/tihonspec
./setup.sh
```

### Commands Not Appearing in Claude Code

1. Restart Claude Code
2. Check `.claude/commands/` exists
3. Verify files have `.md` extension

## Updating TihonSpec

```bash
cd /path/to/tihonspec
git pull

# Re-run installer to update commands
./setup.sh --all --target /path/to/your/project
```

## Manifest File

Installation creates `.tihonspec/.manifest.yaml`:

```yaml
version: "1.0"
installed_at: "2025-12-04T14:31:03Z"
source_repo: "tihonspec"
prefix: "ths"  # if specified
providers:
  claude:
    enabled: true
    files_count: 13
  github:
    enabled: true
    files_count: 13
```

Use manifest to track installation status and version.
