---
id: opensource-preparation
title: Open-Source Release Preparation — Final Cleanup
status: proposed
created: 2025-07-19
---

## Problem

The project is being prepared for open-source release. A "Clean code" commit (`428fa05`) already sanitized most secrets and personal data. However, a few tracked files still contain personal identifiers that should be cleaned before publishing.

## Current State (post-cleanup)

### ✅ Already Cleaned

| Item | Status |
|------|--------|
| `.env.example` | ✅ Placeholders only |
| `.env` | ✅ Gitignored |
| `/secrets/*` | ✅ Gitignored |
| `/config/*.key` | ✅ Gitignored |
| `config/credentials.yml.enc` | ✅ Encrypted, master.key not in repo |
| `*.sqlite3` | ✅ Gitignored |
| `/storage/*`, `/log/*` | ✅ Gitignored |
| `story-12-production-deployment.md` | ✅ Cleaned in "Clean code" commit |
| `app/views/` | ✅ No hardcoded bot names |
| CI workflow | ✅ No system tests, pnpm + build steps added |
| `spec/system/` | ✅ Deleted |
| Git history | ✅ Rewritten (filter-repo), force pushed |
| Merge conflicts | ✅ Resolved |

### 🟡 Remaining — Personal Data in Tracked Files

| File | Issue | Risk |
|------|-------|------|
| `.project/deployment-quickstart.md` | Contains `fedosov.me` domain (3 occurrences), `@inbox_fl_bot` (2 occurrences) | LOW |
| `.project/stories/story-13-ui-ux-improvements.md` | Contains `t.me/inbox_fl_bot` link (1 occurrence) | LOW |
| `openspec/RUNBOOK.md` | Contains `denis@192.168.50.60`, WireGuard IP `10.8.0.5` | LOW |

### 🟢 Missing — Standard Open-Source Files

| File | Status |
|------|--------|
| `LICENSE` | ❌ Missing |
| `CONTRIBUTING.md` | ❌ Missing |
| `README.md` | ⚠️ Exists but may need update for self-hosting guide |

## Solution

1. Sanitize remaining 3 files with personal data
2. Add LICENSE (MIT recommended)
3. Add CONTRIBUTING.md
4. Update README.md with self-hosting instructions
5. Revoke old Telegram bot token (external action)

## Scope

### In Scope
- Sanitize `.project/deployment-quickstart.md`
- Sanitize `.project/stories/story-13-ui-ux-improvements.md`
- Sanitize `openspec/RUNBOOK.md`
- Add LICENSE, CONTRIBUTING.md
- Update README.md

### Out of Scope
- Git history (already rewritten)
- CI/CD for public repo (already configured)
- Telegram bot token regeneration (external, manual action)
