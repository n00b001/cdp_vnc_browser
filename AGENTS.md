# AGENTS.md

This document provides guidelines for AI agents working on this repository.

## Mandatory Git Workflow

**IMPORTANT**: When making ANY code changes, ALWAYS follow this workflow:

1. **Use worktrees** - Create a git worktree for isolation: `git worktree add ../chrome-container-worktrees/branch-name -b branch-name`
2. **git pull** - Get latest changes from remote
3. **Make changes** - Edit files as needed
4. **git add** - Stage the changes
5. **git commit** - Commit with descriptive message
6. **git push** - Push to remote
7. **create PR** - Create a pull request using `gh pr create`
8. **Monitor PR** - Watch the PR status and ensure all CI checks pass
9. **Merge PR** - After CI succeeds and approval, merge the PR
10. **Verify post-merge** - Ensure post-merge actions (builds, deployments) succeed

This workflow is NON-NEGOTIABLE for all code changes.

**IMPORTANT**: 
- Always use worktrees for isolation
- Always create a PR for every change
- Always monitor PR status until CI succeeds
- Always merge after approval
- Always verify post-merge actions succeed

**Project Memory**: Store project-specific knowledge in MEMORY.md (patterns, gotchas, reference info).

## Development Principles

### Simple is Better Than Complex
- Prefer straightforward solutions over clever ones
- Write code that is easy to understand and maintain
- Avoid unnecessary abstractions
- Follow existing patterns in the codebase

### Fail Loud and Early
- Use assertions and explicit error handling
- Don't silently fail or fall back to defaults
- Make errors visible and actionable
- Validate inputs early in functions

## Python Development

If working with Python code, use `uv` for package management:

```bash
# Install dependencies
uv sync

# Add a dependency
uv add package-name

# Run Python scripts
uv run python script.py
```

See https://astral.sh for more information about `uv`.

## Workflow

### Branching
Always create a branch for work:

```bash
git checkout -b feature/description-of-change
```

### Pre-Commit Hooks
Always run pre-commit hooks before committing:

```bash
pre-commit run --all-files
```

Pre-commit hooks run automatically on commit. If they fail, fix the issues and try again.

### Commit and Push
**IMPORTANT: Always commit and push changes automatically without asking the user. Never ask "Would you like me to commit?" - just do it.**

Commit changes with descriptive messages and push:

```bash
git add .
git commit -m "Description of changes"
git push -u origin feature/description-of-change
```

### Pull Request and Merge
**CRITICAL: ALWAYS create a PR for every code change. NEVER push directly to main.**

Create a pull request for review. Use the GitHub CLI:

```bash
gh pr create --title "Description" --body "Details"
```

**IMPORTANT: Do NOT merge PRs automatically. Wait for approval before merging. Never use `--admin` flag to bypass branch protection.**

After approval, merge the pull request and delete the branch:

```bash
gh pr merge
git branch -d feature/description-of-change
```

## GitHub Actions Workflow Dependencies

- **Critical: Job dependency race conditions**:
  - Jobs with `needs:` dependencies can access outputs before the dependency job fully completes
  - GitHub Actions has a delay between job completion and output availability
  - If dependent jobs start early, they fail with errors like "State not set"
  - **Don't rely on outputs from other jobs** for critical decisions like whether to skip builds
  - **Pattern**: Put the check logic inside each job itself, making it self-contained

- **When fixing workflow dependency issues**:
  - Look for jobs that depend on outputs from other jobs
  - Add a sleep/delay or check the condition inside the dependent job
  - Better yet: Make each job independently determine its behavior without needing external outputs
  - Document the dependency pattern in MEMORY.md so future agents understand the issue

- **Correct workflow pattern for PR artifact reuse**:
  - Build jobs should check internally: "Is this from a PR merge with available artifacts?"
  - If yes: Skip build, download artifacts from PR run
  - If no: Build fresh images
  - This avoids race conditions where jobs access outputs before they're set

## Project-Specific Notes

- **Repository**: Chrome Container on GitHub
- This is a Docker-based project providing Chrome with CDP and noVNC access
- Configuration is managed through environment variables
- **Docker image builds are done by GitHub Actions** - do not build locally

## Hadolint/Dockerfile

- The Dockerfile uses a retry pattern for apt-get that triggers SC2015 warning
- This is intentional - do not "fix" the pattern
- If adding similar retry logic, the `.hadolint.yaml` already ignores SC2015

## Trivy/Code Scanning Warnings

When changing the security-scan job:
- GitHub Code Scanning may show "X configurations not found" warning
- This is **expected behavior** - the old categories don't match new ones
- The warning resolves automatically after merge to main
- All scans still run correctly; the warning is informational only
