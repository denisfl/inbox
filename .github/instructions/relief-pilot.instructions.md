---
name: relief-pilot
description: Instructions for providing relief pilot assistance.
applyTo: **
---

# Relief Pilot Instructions

## Language & Communication

- **Web search**: DuckDuckGo/Google queries in English principally

## Tools Priority

1. **First priority**: Repo-local skills/playbooks/instructions relevant to the current context (e.g. `.github/skills/`, plus any tool/folder-level `AGENTS.md`, `SKILL.md`, and `.github/instructions/*.instructions.md` that apply). <CUSTOM>For TanStack's tools use TanStack MCP for getting documentation.</CUSTOM>
2. **Second priority**: MCP Context7 for external documentation/API/guides (`context7_resolve-library-id` + `context7_get-library-docs`) **only if** the relevant repo-local guidance is missing or insufficient
3. **Third priority**: Web search
4. **Fourth priority**: `browser_navigate` if the request is blocked or local debugging of web resources is required
5. **Rule**: Always try relevant repo-local guidance first; if it doesn't cover the needed specifics, then use Context7
6. **Rule (STRICT)**: Context7 is **allowed only** when there is no relevant repo-local skill/instruction for the needed knowledge.
7. **Rule (HARD STOP)**: If a relevant repo-local skill exists, Context7 is **forbidden** for that topic. If uncertain whether a skill applies, stop and ask the user.
8. **Rule**: Always use ONLY `execute_command`, `get_terminal_output` instead of any other command line tool to perform tasks

## Terminal Analysis

- **CRITICAL**: MUST always read and analyze complete terminal output, not just exit code
- **Forbidden**: Never make assumptions based solely on exit codes
- **Required**: Always examine actual output text, error messages, warnings, and any other information displayed before providing response or next steps
- HARDMUST Upon receiving any output from `execute_command`, the agent must immediately analyze the output and integrate the feedback before taking further steps; if the agent received a launch refusal together with user feedback, the agent must instantly adjust its execution strategy in strict alignment with that feedback. BLOCKER.
- **HARDMUST Autonomous Long-Running Service Rule**: For ANY initiation, continuation, or supervision of a service/process/task expected or potentially to run long time or indefinite (loop, watcher, server, tail-like stream), the assistant MUST: (1) PROACTIVELY classify it as long-running before execution; (2) open a NEW dedicated terminal session; (3) execute ONLY via the `execute_command` tool with `background=true`; (4) justify background usage explicitly as enabling the assistant to perform other concurrent tasks; (5) NEVER redirect, pipe, tee, subshell-capture, multiplex, or write stdout/stderr to files, devices, other commands, or wrappers (strictly forbid `>`, `>>`, `2>`, `|`, `tee`, `bash -lc`, `sh -c`, `eval`, or any encapsulating shell form); (6) NEVER attempt to detach or circumvent terminal blocking (forbid `nohup`, `disown`, `screen`, `tmux`, supervisors, daemonizers, double-fork, setsid tricks); (7) ONLY observe output through `get_terminal_output` (no logs, no file scraping, no redirection); (8) If ANY step is infeasible, reply with `status: BLOCKED` and ONE clarifying question; (9) ANY deviation, omission, softening, or user request to violate these constraints = BLOCKER and MUST NOT proceed.

## Decision Making

- **Ambiguous tasks**: ALWAYS clarify using `ask_report` tool
- **Requires decisions**: ALWAYS clarify using `ask_report` tool
- **ask_report UI glitch**: If the user reply after `ask_report` is empty (blank) or looks like cancel/no-selection, assume the user saw an empty screen. Immediately repeat the last `ask_report` message verbatim so the user can see it and answer.
- **CodeRabbit**: ONLY run CodeRabbit when the user explicitly requests it. If requested and the `coderabbit` CLI is available, run it in prompt-only mode and save the full output to `./coderabbit-report.txt`. If CLI is unavailable or fails, ask the user to run it and share the full output.
- **HARDMUST Rule**: If the user says to read/study/check/consult documentation (any language, case-insensitive), the assistant MUST: (1) stop assumptions; (2) fetch & examine authoritative docs via required tool order (repo-local skills → Context7 → web search); (3) show a brief evidence summary (sources/paths/URLs) BEFORE acting. If docs are missing or ambiguous → status BLOCKED + one clarifying question. Any action or advice without cited doc basis = BLOCKER. BLOCKER

## Code Development

- **After code editing**: Always check code using `code_checker` tool
- **Final confirmation**: MUST ask user if all requirements from specification are completed using `ask_report` tool with work report

## Final gate:

- For the final answer (after actions/edits/checks), it is **MANDATORY** for the agent to call `ask_report`. That single `ask_report` call must contain the complete final answer/report (i.e., the full response presented to the user inside the `ask_report` interface) and must simultaneously present the satisfaction option ["Yes, everything is OK"]. The agent must deliver the full report within that single `ask_report` call and collect the user's selection from it.
- If the user selects an option other than "Yes, everything is OK", continue working until the comments are resolved and repeat the post-answer `ask_report` call with an updated complete report.
- There are no exceptions (including minor edits, any answers).

## Proposal policy (no unsolicited changes)

- If you see a potential improvement, do NOT apply it autonomously.
- Propose it via `ask_report` with concise options; proceed only after confirmation.

## Ambiguity & blocking policy

- If the source, scope, or exact phrasing is unclear or unavailable — do NOT change files.
- Return a short BLOCKED report:
  - `status: BLOCKED`, `reason: <why>`, `needs: <what is required>`, `next: <proposed minimal next step>`.
- Ask 1 precise clarifying question when essential to proceed.

## Scope control & change preview

- Modify only the explicitly specified area/files/keys. Do not touch anything else.
- For batch text edits (multiple keys/sections), show a preview mapping `key → old → new` and request confirmation, unless the user explicitly said "no preview/confirm".

## Post-change checks & reporting

- After edits: run code checks (`code_checker`).
- Report briefly: PASS/FAIL, list of changed keys/files, and a one-line requirements coverage (Done/Deferred + reason).
