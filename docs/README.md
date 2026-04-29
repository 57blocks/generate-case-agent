# Documentation Index

## Quick Start

**New to the project?** Start here:

1. [ENVIRONMENT_GUIDE.md](../ENVIRONMENT_GUIDE.md) - Quick reference for environment setup
2. [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) - Complete environment configuration guide
3. [VSCODE_SETUP.md](VSCODE_SETUP.md) - VSCode configuration

## Core Guides

### Environment Configuration

- **[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)** - Complete guide to environment setup and configuration
  - Environment file creation
  - Project-environment mapping
  - Running tests
  - Mixed environment mode
  - Troubleshooting

- **[PROJECT_ENVIRONMENT_MAPPING.md](PROJECT_ENVIRONMENT_MAPPING.md)** - Detailed project-to-environment mapping
  - How automatic detection works
  - Adding new projects
  - Override mechanisms
  - Best practices

### Development Setup

- **[VSCODE_SETUP.md](VSCODE_SETUP.md)** - VSCode configuration and limitations
  - Why green play button loads all environments
  - Recommended command-line approach
  - Alternative configurations

### Extending the System

- **[ADDING_NEW_REGIONS.md](ADDING_NEW_REGIONS.md)** - Adding new regions/environments
  - Step-by-step guide
  - Code changes required
  - Verification steps

## Additional Topics

### CI/CD Integration

See [ENVIRONMENT_SETUP.md#cicd-integration](ENVIRONMENT_SETUP.md#cicd-integration) for GitHub Actions examples.

### Git Optimization

- **[GIT_OPTIMIZATION.md](GIT_OPTIMIZATION.md)** - Git configuration and optimization

### Slack Integration

- **[SLACK_NOTIFICATION_QUICK_START.md](SLACK_NOTIFICATION_QUICK_START.md)** - Quick start guide
- **[SLACK_SETUP.md](SLACK_SETUP.md)** - Detailed setup
- **[SLACK_INTEGRATION_SUMMARY.md](SLACK_INTEGRATION_SUMMARY.md)** - Integration summary

## Quick Reference

### Environment Files

```
.env.stg      # Staging environment
.env.prod     # Production environment
.env.ca       # CA region environment
.env.example  # Template
```

### Common Commands

```bash
# Run tests with auto-detected environment
npx playwright test --project=connectors

# Override environment
TEST_ENV=stg npx playwright test --project=connectors

# Verify configuration
npm run verify-env

# Debug mode
npm run debug
```

### Project Mapping

| Project | Environment |
|---------|-------------|
| connectors, democase, poc | Production |
| ca | CA |
| main, others | Staging |

## Getting Help

1. **Environment issues?** → [ENVIRONMENT_SETUP.md#troubleshooting](ENVIRONMENT_SETUP.md#troubleshooting)
2. **VSCode issues?** → [VSCODE_SETUP.md](VSCODE_SETUP.md)
3. **Project mapping unclear?** → [PROJECT_ENVIRONMENT_MAPPING.md](PROJECT_ENVIRONMENT_MAPPING.md)

## Documentation Philosophy

These docs follow these principles:

- **Concise** - Only essential information
- **Practical** - Focus on how-to, not theory
- **English** - All docs in English for consistency
- **Minimal** - No verbose analysis or temporary debug docs

---

**Need something not covered here?** Check the main project guide: [CLAUDE.md](../CLAUDE.md)
