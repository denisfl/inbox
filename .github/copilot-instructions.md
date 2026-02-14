# AI Coding Instructions

## 0. Critical Requirement

- **MANDATORY**: Agent MUST follow the instructions in `.github/instructions/relief-pilot.instructions.md` at all times.

## 1. Mandatory Protocols

### 1.1 Timeouts
- **ALWAYS** specify `timeout` for `execute_command` (e.g., 30000ms)
- Set timeouts for HTTP requests (e.g., `httpx.AsyncClient(timeout=10.0)`)
- Purpose: prevent indefinite hanging
- Max single wait: 5 minutes; if still running — may extend by another 5 min
- Max total duration: 30 minutes

### 1.2 Final Reporting (`ask_report`) — CRITICAL
**⚠️ VIOLATION = PROJECT FAILURE**

- **EVERY** response MUST end with `ask_report` — no exceptions
- Complete answer/report must be inside `ask_report`, not plain text
- Applies to: answers, clarifications, error reports, partial results, everything
- **Empty user reply handling**: if user response after `ask_report` is empty/blank — retry with restructured output (same content, different format/parameters)

### 1.3 Skills & Docs Attribution
Every final report MUST include at the end:
- `Skills used: <list>` — if any skills were consulted
- `Docs used: <list>` — if any external documentation was fetched

## 2. File & Server Safety

### 2.1 Remote Servers (SSH)
**FORBIDDEN**: modifying git-tracked repo files on remote servers

### 2.2 Local Workspace (Git)
**FORBIDDEN**: any command that modifies repo/history/remotes
- `git commit`, `push`, `reset`, `rebase`, `merge`, `cherry-pick`, `revert`, `checkout`, `switch`, `pull`, `fetch --prune`, `clean`

**ALLOWED** (read-only):
- `git status`, `diff`, `log`, `show`, `blame`, `grep`

**File deletion**: use `trash` instead of `rm -rf` (blocked by hook)

## 3. Code Quality Standards

### 3.1 Production Code
**PROHIBITED**:
- Silent fallbacks (`or "default"`, `get() or fallback`)
- Mock/stub implementations
- Hardcoded placeholders (API keys, defaults)
- Generic error messages
- Bare `except:` clauses

**REQUIRED**:
- Explicit error handling (fail fast)
- Real implementations only
- `TODO`/`FIXME` comments for unimplemented features

### 3.2 Configuration
- ENV variables only — no hardcoded credentials
- Follow `.project/specs.md` for TypeScript, testing, quality standards
- Use `react-best-practices` skill for React/TypeScript patterns

## 4. Project Context

### 4.1 Required Reading
Before non-trivial requests, read:
- `.project/about.md` — if present
- `.project/architecture.md` — system architecture, components, interactions
- `.project/specs.md` — technical requirements, versions, patterns
- `.project/project-context.md` — project-specific context, baselines

## 5. Dependencies & Versions
All component versions defined in repo docs:
- `.project/project-context.md`
- `.project/specs.md`

**Version policy**:
- Downgrading package versions is **FORBIDDEN**
- Upgrading is allowed
- If specified/higher version is incompatible — provide detailed report to user with reasons and alternatives

## 6. Task-Specific Workflows

### 6.1 Code Review Request
When user asks to review changed files:
1. Run `git diff` or `git status` to identify uncommitted changes
2. Use `coderabbit` skill — execute its review script
3. Present CodeRabbit report to user
4. Ask which issues to fix, provide recommendations
5. **Ignore** suggestions for archived changes (`openspec/changes/archive/`) or outdated documents

### 6.2 Changelog Request
When user asks to write changelog (before commit):
1. Use `changelog` skill for format
2. Use `commits` skill for branch name and commit message conventions
3. Write/update CHANGELOG.md with `[Unreleased]` section
4. In final `ask_report` — **DO NOT duplicate changelog content**
5. Final report must contain ONLY:
  - Brief confirmation: "Changelog is ready" if it's really ready (or error details)
  - 3 branch name options (conventional: `feat/`, `fix/`, `refactor/`, etc.)
  - 3 commit message variants (short/medium/detailed) following Conventional Commits
  - Pull Request description (summarized, not full changelog)

### 6.3 Page Inspection Request
When user asks to check/test/fix a web page:
- **MUST** use `chrome-devtools-mcp` for inspection
- Verify visual/functional compliance as requested

## 7. Session Completion
Agent run must NOT require git operations that modify the repository.
Human performs commit/push manually outside agent run.
