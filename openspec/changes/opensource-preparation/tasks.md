---
id: opensource-preparation
artifact: tasks
---

## Tasks

### 1. ~~Sanitize remaining personal data~~ ✅ DONE

- [x] 1.1 `.project/deployment-quickstart.md` — replaced `fedosov.me` → `example.com`
- [x] 1.2 `.project/deployment-quickstart.md` — replaced `inbox.fedosov.me` → `inbox.example.com` (was already clean)
- [x] 1.3 `.project/deployment-quickstart.md` — replaced `@inbox_fl_bot` → `@your_bot_name`
- [x] 1.4 `.project/stories/story-13-ui-ux-improvements.md` — replaced `t.me/inbox_fl_bot` → `t.me/your_bot_name`
- [x] 1.5 `openspec/RUNBOOK.md` — replaced `denis@192.168.50.60` → `user@your-rpi-ip`
- [x] 1.6 `openspec/RUNBOOK.md` — replaced WireGuard `10.8.0.5` → `10.8.0.x`

### 2. ~~Add LICENSE file~~ ✅ DONE

- [x] 2.1 MIT license chosen
- [x] 2.2 Created `LICENSE` file in project root

### 3. ~~Add CONTRIBUTING.md~~ ✅ DONE

- [x] 3.1 Created `CONTRIBUTING.md` with prerequisites, dev setup, code style, testing, PR guidelines

### 4. ~~Update README.md~~ ✅ DONE

- [x] 4.1 Project description, features list, tech stack table
- [x] 4.2 Docker Quick Start guide (clone, .env, secrets, build, webhook)
- [x] 4.3 Development setup (Ruby, Node, pnpm, bin/dev)
- [x] 4.4 Environment variables reference table
- [x] 4.5 Architecture diagram (ASCII)
- [x] 4.6 License badge and contributing link

### 5. External actions (manual)

- [ ] 5.1 Revoke old Telegram bot token via BotFather `/revoke`
- [ ] 5.2 Generate new bot token
- [ ] 5.3 Update local `.env` with new token

### 6. Final verification

- [ ] 6.1 Run: `grep -rn "8048540749\|80646805" . --include="*.rb" --include="*.md" --include="*.yml" --include="*.js" --include="*.css" --include="*.erb" | grep -v ".git/" | grep -v node_modules/` — should return 0
- [ ] 6.2 Run: `grep -rn "fedosov" . --include="*.rb" --include="*.md" --include="*.yml" --include="*.js" --include="*.erb" | grep -v ".git/" | grep -v node_modules/` — should return 0
- [ ] 6.3 Run: `grep -rn "inbox_fl_bot" . --include="*.rb" --include="*.md" --include="*.yml" --include="*.js" --include="*.erb" | grep -v ".git/" | grep -v node_modules/` — should return 0
- [ ] 6.4 Run: `grep -rn "192.168.50" . --include="*.rb" --include="*.md" --include="*.yml" | grep -v ".git/"` — should return 0
- [ ] 6.5 Run CI (push to GitHub, verify all 3 jobs pass)
