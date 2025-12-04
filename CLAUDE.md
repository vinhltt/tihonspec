# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

**TihonSpec** - "Tiny kit, mighty power"

A lightweight yet powerful specification-driven AI agent development toolkit. Provides structured workflows for feature development and unit test generation with multi-platform support.

## Repository Structure

```
tihonspec/
├── .tihonspec/           # TihonSpec core system
│   ├── commands/        # Source commands (feature, ut)
│   ├── scripts/bash/    # Automation scripts
│   └── templates/       # Workflow templates
└── docs/                # Documentation
```

## MCP Server Configuration

This project uses MCP servers configured in `.mcp.json`:

- **serena**: Semantic coding tool for codebase analysis
- **context7**: Up-to-date library documentation

## Working with Commands

### Feature Commands
- `/feature.specify` - Create feature specification
- `/feature.clarify` - Clarify requirements
- `/feature.plan` - Generate implementation plan
- `/feature.tasks` - Break down into tasks
- `/feature.implement` - Execute implementation

### Unit Test Commands
- `/ut.specify` - Create test specification
- `/ut.generate` - Generate unit tests
- `/ut.run` - Execute tests

## Philosophy

- **KISS** - Keep It Simple, Stupid
- **YAGNI** - You Aren't Gonna Need It
- **DRY** - Don't Repeat Yourself

## Vietnamese Language Support

This repository supports Vietnamese documentation and prompts alongside English.
