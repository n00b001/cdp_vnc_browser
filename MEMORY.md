# Memory

## Mandatory Git Workflow

When making ANY code changes, ALWAYS follow this workflow:

1. **git pull** - Get latest changes from remote
2. **git branch** - Create a feature branch for the work
3. **git add** - Stage the changes
4. **git commit** - Commit with descriptive message
5. **git push** - Push to remote
6. **create PR** - Create a pull request using `gh pr create`

This workflow is NON-NEGOTIABLE for all code changes.

**IMPORTANT**: You must always pull origin/main into your branch whenever making a change. You must resolve conflicts if they exist.

## Important Rules

- **NEVER push directly to main** - Always create a branch and PR
- **Always create a PR** - Every code change must go through a pull request
- **Never merge PRs without approval** - Create PR and wait for review/approval before merging
- **Always monitor PR after pushing** - After pushing a PR, always monitor it and ensure the CI checks pass
- Do not use `--admin` flag to bypass branch protection rules

## GitHub Actions Workflow Dependencies

- **Job dependency race condition**: Jobs with `needs:` dependency can sometimes start before the dependency job's outputs are fully available
  - In `.github/workflows/docker-publish.yml`, build jobs depend on `check-pr-status` to get `can_skip_build` output
  - However, outputs aren't immediately available to dependent jobs - there's a small delay
  - If dependent jobs start too early, they can't access the output and fail with "State not set" or similar errors
  - **Solution**: Don't have build jobs depend on external output. Instead, check the PR status logic inside each build job itself

- **Workflow `needs` clause behavior**:
  - `needs: [job1, job2]` means the job waits for BOTH jobs to complete
  - The dependency job must finish completely (including output setting) before the dependent job starts
  - GitHub Actions has a delay of several seconds between job completion and output availability
  - **Pattern**: Have self-contained logic in each job that can independently decide whether to run, rather than relying on outputs from a separate job

- **Correct pattern for PR artifact reuse**:
  - Each build job should check if it came from a PR merge and has available artifacts
  - If yes, skip build and download artifacts from PR run
  - If no, build fresh images
  - This avoids the race condition where jobs try to access outputs before they're available

## Blacksmith Runners

This project uses Blacksmith runners for faster GitHub Actions builds:

- **Runner Types**:
  - `blacksmith-2vcpu-ubuntu-2404` - Lightweight tasks (pre-commit, checks)
  - `blacksmith-32vcpu-ubuntu-2404` - Heavy builds (Docker image building)

- **Blacksmith Actions**:
  - `useblacksmith/setup-docker-builder@v1` - Sets up the Blacksmith Docker builder
  - `useblacksmith/build-push-action@v2` - Blacksmith's optimized buildx action

- **Reference**: See `.github/workflows/docker-publish.yml` for the complete setup pattern

## Repository and Package Naming

- **Docker Images**: `ghcr.io/xfanth/chrome-cdp-novnc`
- **Image tags**: `latest` and SHA-based tags
- **Full image name**: `ghcr.io/xfanth/chrome-cdp-novnc:latest`

## Hadolint Configuration

The Dockerfile uses a retry pattern for apt-get commands:
```dockerfile
RUN for i in 1 2 3; do \
        apt-get update && \
        apt-get install -y ... && \
        rm -rf /var/lib/apt/lists/* && \
        break || \
        (echo "Retry $i failed, waiting 10 seconds..." && sleep 10); \
    done
```

This triggers hadolint SC2015 warning (`A && B || C is not if-then-else`). The pattern is intentional for retry logic, so we ignore SC2015 in `.hadolint.yaml`.

## Available Tools

The following tools are available:
- `read` - Read files from filesystem
- `write` - Write files to filesystem
- `edit` - Edit existing files
- `bash` - Execute shell commands
- `glob` - Search for files by pattern
- `grep` - Search file contents
- `git_*` - Git operations (status, diff, commit, add, branch, etc.)
- `sequential-thinking` - Problem-solving through structured thinking
- `jina-mcp-server_*` - Web search, URL reading, image search, etc.
- `playwright_browser_*` - Browser automation
- `memory_*` - Knowledge graph operations
- `gemini-cli_*` - Gemini AI interactions
- `mcp-server-analyzer_*` - Code analysis (ruff, vulture)
- `filesystem_*` - File operations
- `mcp_everything_*` - Utility functions

## Project Structure

```
chrome-container/
├── .github/workflows/    # CI/CD workflows
├── scripts/              # Entry point and startup scripts
├── Dockerfile            # Multi-stage Docker build
├── nginx.conf            # Nginx reverse proxy config
└── supervisord.conf      # Process supervision config
```

## Common Commands

```bash
# Build locally
docker build -t chrome-cdp-novnc .

# Run container
docker run -d -p 5900:5900 -p 9222:9222 -p 6080:6080 chrome-cdp-novnc

# Access points:
# - VNC: localhost:5900
# - noVNC (web): http://localhost:6080
# - Chrome DevTools Protocol: localhost:9222
```
