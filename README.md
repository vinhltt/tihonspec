<p align="center">
  <img src="assets/images/banner.png" width="500" alt="TihonSpec Banner">
</p>

# TihonSpec

**"Tiny kit, mighty power"** - Specification-driven AI agent development toolkit

A lightweight yet powerful template repository for structured AI-assisted development workflows. Provides specification-driven feature development and unit test generation with multi-platform support.

> **Fork Note:** This project is a fork of [GitHub Speckit](https://github.com/github/spec-kit)

---

## 🎯 Philosophy

TihonSpec follows three core principles:

- **KISS** - Keep It Simple, Stupid
- **YAGNI** - You Aren't Gonna Need It
- **DRY** - Don't Repeat Yourself

Focus on **WHAT** users need, not **HOW** to implement.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| **Specification-Driven** | Define features before implementation |
| **Multi-Provider Support** | Claude Code + GitHub Copilot |
| **Multi-Platform** | macOS, Linux, Windows (WSL) |
| **Multi-Framework Testing** | 15+ test frameworks across 7+ languages |
| **Hierarchical Workspaces** | Parent/child project management |
| **Configuration-Driven** | YAML-based customization |

---

## 🚀 Quick Start

### Installation

```bash
# Clone TihonSpec
git clone https://github.com/your-org/tihonspec.git
cd tihonspec

# Interactive installation
./setup.sh

# Or install all providers to a target project
./setup.sh --all --target /path/to/project
```

### Installation Options

| Option | Description |
|--------|-------------|
| `--all` | Install all providers (Claude + Copilot) |
| `--target <path>` | Target project directory |
| `--prefix <name>` | Add prefix to commands (e.g., `ths`) |
| `--config-only` | Config file only, inherits parent commands |

### What Gets Installed

```
your-project/
├── .tihonspec/                    # Core system
│   ├── scripts/bash/              # Automation scripts
│   ├── templates/                 # Markdown templates
│   ├── memory/                    # Constitution file
│   └── .tihonspec.env.example     # Environment template
│
├── .claude/commands/              # Claude Code commands
│   ├── feature/                   # Feature workflow
│   └── ut/                        # Unit test workflow
│
└── .github/prompts/               # GitHub Copilot commands
```

---

## 📋 Available Commands

### Feature Development Workflow

```
/feature.specify  → Create feature specification
/feature.clarify  → Clarify requirements
/feature.plan     → Generate implementation plan
/feature.tasks    → Break down into tasks
/feature.analyze  → Analyze codebase for feature
/feature.implement→ Execute implementation
/feature.checklist→ Generate QA checklist
/feature.status   → Check implementation status
```

**Workflow:**
```
specify → clarify → plan → tasks → implement → checklist
```

### Unit Test Workflow

```
/ut.create-rules  → Define testing framework & rules
/ut.plan          → Create test plan & phases
/ut.generate      → Generate test files
/ut.check-rules   → Validate UT rules exist
/ut.auto          → Full automation (plan → generate → run)
```

**Workflow:**
```
create-rules → plan → generate → run
         ↑_____ or use /ut.auto _____↓
```

### Project Management

```
/project.init     → Initialize new project/workspace
/project.list     → List all projects in workspace
/project.sync     → Sync docs between workspaces
```

---

## 🧪 Supported Test Frameworks

| Language | Frameworks |
|----------|------------|
| JavaScript/TypeScript | Vitest, Jest, Mocha, Jasmine |
| Python | Pytest, unittest |
| Ruby | RSpec, Minitest |
| Java | JUnit, TestNG |
| PHP | PHPUnit, Pest |
| .NET (C#) | xUnit, NUnit, MSTest |
| Go | testing, testify |

---

## 📁 Repository Structure

```
tihonspec/
├── .tihonspec/                    # Core system
│   ├── commands/                  # AI provider commands (17 files)
│   │   ├── feature/               # Feature workflow (9 commands)
│   │   ├── ut/                    # Unit test workflow (5 commands)
│   │   └── project/               # Project management (3 commands)
│   ├── scripts/bash/              # Automation scripts (15 files)
│   │   ├── feature/               # Feature operations
│   │   ├── ut/                    # Unit test operations
│   │   ├── common.sh              # Shared utilities
│   │   └── common-env.sh          # Environment variables
│   ├── templates/                 # Workflow templates (17 files)
│   │   ├── spec-template.md       # Feature specification
│   │   ├── plan-template.md       # Implementation plan
│   │   ├── tasks-template.md      # Task breakdown
│   │   └── ut/                    # Unit test templates
│   ├── memory/                    # AI context
│   │   └── constitution.md        # Project governance
│   ├── examples/                  # Example configurations
│   │   ├── project-tihonspec.yaml
│   │   └── workspace-tihonspec.yaml
│   └── docs/                      # Internal documentation
│
├── docs/                          # User documentation
│   ├── setup-guide.md             # Installation guide
│   ├── configuration-guide.md     # Configuration reference
│   └── ut-workflow-guide.md       # Unit test workflow guide
│
├── setup.sh                       # Installation script
├── README.md                      # This file
├── CLAUDE.md                      # Claude Code guidance
└── LICENSE
```

---

## ⚙️ Configuration

### Workspace Configuration

Create `.tihonspec/.tihonspec.yaml`:

```yaml
version: "1.0"
name: "my-project"
type: "workspace"

docs:
  path: "ai_docs"
  rules: []

metadata:
  language: "typescript"
  framework: "vue"
  test_framework: "vitest"

commands:
  test: "pnpm test"
  build: "pnpm build"
  lint: "pnpm lint"

projects: []  # For multi-project workspaces
```

### Environment Variables

```bash
cd your-project/.tihonspec
cp .tihonspec.env.example .tihonspec.env
# Edit with your settings
```

Key variables:
- `TIHONSPEC_PREFIX_LIST` - Allowed task ID prefixes
- `TIHONSPEC_DEFAULT_FOLDER` - Default folder for specs
- `TIHONSPEC_SPECS_ROOT` - Root directory for specs
- `TIHONSPEC_MAIN_BRANCH` - Primary branch name

---

## 📖 Task ID System

**Format:** `[folder/]prefix-number`

**Examples:**
```
pref-001           # Default folder
PREF-001           # Case-insensitive
hotfix/pref-123    # Custom folder
```

**Usage:**
```bash
/feature.specify pref-001 "Add user authentication"
/ut.auto pref-001
```

---

## 🔄 Workflows

### Feature Development

1. **Specify**: Define WHAT the feature does (user-focused)
2. **Clarify**: Resolve ambiguities (max 3 clarifications)
3. **Plan**: Design architecture and approach
4. **Tasks**: Break into implementable units
5. **Implement**: Code with guidance
6. **Checklist**: Validate quality

### Unit Testing

1. **Create Rules**: One-time framework setup
2. **Plan**: Design test structure and phases
3. **Generate**: Create test files
4. **Run**: Execute and report

Or use `/ut.auto` for full automation.

---

## 📚 Documentation

| Guide | Description |
|-------|-------------|
| [Setup Guide](docs/setup-guide.md) | Installation instructions |
| [Configuration Guide](docs/configuration-guide.md) | Configuration reference |
| [UT Workflow Guide](docs/ut-workflow-guide.md) | Unit test workflow |

---

## 🛠️ Troubleshooting

### "Cannot install to source directory"

Run from a different target:
```bash
./setup.sh --target /path/to/your/project
```

### "Source directory not found"

Ensure you're in the TihonSpec repo:
```bash
cd /path/to/tihonspec
./setup.sh
```

### Commands not appearing

1. Restart Claude Code / VS Code
2. Check `.claude/commands/` exists
3. Verify files have `.md` extension

---

## 🔧 Updating

```bash
cd /path/to/tihonspec
git pull

# Re-run installer
./setup.sh --all --target /path/to/your/project
```

---

## 📝 Manifest

Installation creates `.tihonspec/.manifest.yaml`:

```yaml
version: "1.0"
installed_at: "2025-12-06T10:30:00Z"
source_repo: "tihonspec"
prefix: "ths"  # if specified
providers:
  claude:
    enabled: true
    files_count: 17
  github:
    enabled: true
    files_count: 17
```

---

## 📊 Statistics

| Category | Count |
|----------|-------|
| Command Files | 17 |
| Script Files | 15 |
| Templates | 17 |
| Test Frameworks | 15+ |
| Languages Supported | 7+ |
| AI Providers | 2 |

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/my-feature`
3. Commit changes: `git commit -m "Add my feature"`
4. Push to branch: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

See [LICENSE](LICENSE) file for details.

---

<p align="center">
  <strong>TihonSpec</strong> - Tiny kit, mighty power 🚀
</p>
