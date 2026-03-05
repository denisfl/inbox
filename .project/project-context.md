## Current Status

- **Project Name:** Inbox
- **Phase:** Phase 3 — Architecture & Context Validation
- **Status:** 🏗️ Planning & Setup
- **Last Updated:** 2026-02-12
- **Next Review:** 2026-02-13

---

## Quick Reference

### What is Inbox?

A **personal note-taking system** running on Raspberry Pi with:

- Block-based editor (like Craft.do, Logseq)
- Telegram bot integration for quick capture
- Local audio transcription (Parakeet v3 via onnx-asr)
- Simple, modern interface
- Complete privacy (no cloud)
- Single user

---

## Initialization Progress (INIT.md)

### ✅ Completed Phases

**Phase 1: Project Foundation** (100%)

- Project scaffolded via `start-vibe-project`
- [about.md](.project/about.md) — Vision, Problem, Goals, Features
- [specs.md](.project/specs.md) — Technology versions locked
- [architecture.md](.project/architecture.md) — 928 lines of detailed architecture

**Phase 2: Skills Discovery** (100%)

- Installed 11 skills for github-copilot:
  - Base: `changelog`, `commits`, `project-creator`, `skill-master`, `social-writer`, `ask-questions-if-underspecified`
  - Tech: `telegram`, `makefile`, `vite`, `vitest`, `react-testing-library`

**Phase 3: Architecture & Context** (In Progress)

- Architecture validated against specs ✅
- Project-context.md being updated ⏳

### ⏳ Remaining Phases

**Phase 4: User Stories**

- Create individual story files from Features
- Prioritize for MVP
- Define acceptance criteria

**Phase 5-6: Final Review & OpenSpec**

- Install/verify OpenSpec
- Initialize with `openspec init`
- Plan Story #1 with `/opsx-ff initial-setup`

---

## Key Technical Decisions

### 1. Technology Stack (Locked Versions)

| Component               | Choice          | Version | Reason                               |
| ----------------------- | --------------- | ------- | ------------------------------------ |
| **Framework**           | Rails           | 8.0.x   | Full-featured, rapid development     |
| **Language**            | Ruby            | 3.3.1   | Productive, readable                 |
| **Database**            | SQLite          | 3.43+   | Zero-config, perfect for single user |
| **Frontend**            | Stimulus JS     | 3.x     | Lightweight, Rails-native            |
| **Queue**               | Sidekiq + Redis | 7.x     | Reliable background jobs             |
| **Audio Transcription** | Parakeet v3 / onnx-asr | 0.6b-v3 | Local transcription, privacy, 25 languages |
| **Deployment**          | Docker          | 20.10+  | Containerization                     |
| **Target**              | Raspberry Pi 5  | —       | Affordable, runs at home             |

**Version Policy:** ⚠️ Downgrading is **FORBIDDEN**. Upgrades allowed after testing.

### 2. Architecture Principles

**Single User by Design**

- Simplifies authentication
- Removes multi-tenancy complexity
- Optimizes for personal use

**Privacy First**

- 100% local processing (no cloud)
- SQLite local database
- Parakeet v3 transcription runs on-device
- No cloud API keys required
- Optional HTTPS for local network

**Minimal Dependencies**

- SQLite (no PostgreSQL needed)
- Stimulus (no React complexity)
- Local AI (no API keys)
- systemd (no Kubernetes)

**Performance Targets**

- API response: <100ms (p95)
- Page load: <500ms
- DB query: <50ms (p95)
- Parakeet v3 transcription: <2min per audio minute

### 3. Deployment Strategy

**Target Platform:** Raspberry Pi 5

- OS: Raspberry Pi OS / Ubuntu
- Runtime: Docker Compose
- Service Manager: systemd
- Monitoring: Health checks + logs

**Services:**

```
- web (Rails + Puma)
- worker (Sidekiq)
- redis (Cache + queue)
- transcriber (Parakeet v3 audio transcription)
```

### 4. Quality Standards

**Testing:**

- Minimum: 80% code coverage
- Target: 85%+
- Critical paths: 100%
- Framework: RSpec + FactoryBot

**Code Quality:**

- Linter: Rubocop
- Formatter: Prettier
- Pre-commit hooks: enabled
- CI quality gates: enforced

**Security:**

- Input validation on all endpoints
- Secrets in environment variables
- Audit logging for actions
- Dependency scanning (bundler audit)

---

## Technical Decisions (Resolved)

### 1. ~~Ollama Model Selection~~ (REMOVED)

**Decision:** Ollama/LLM classification has been **removed** from the project.

**Rationale:**

- Parakeet v3 handles punctuation and capitalization natively
- No need for LLM post-processing or intent classification
- Simplifies architecture and reduces memory usage
- All messages saved as notes directly

---

### 2. Audio Transcription Engine

**Decision:** **Parakeet v3** (nemo-parakeet-tdt-0.6b-v3 via onnx-asr)

**Rationale:**

- ONNX Runtime for fast CPU inference (~18x real-time)
- Supports 25 languages with automatic detection
- Automatic punctuation and capitalization
- No LLM post-processing needed
- FFmpeg converts any audio format (WebM, OGG, MP3) to WAV

**Configuration:**

```bash
TRANSCRIBER_URL=http://transcriber:5000
# TRANSCRIBER_LANGUAGE=ru  # Optional: force language
```

**Expected Performance:**

- Transcription: ~1-2 minutes per audio minute on RPi5
- Memory: ~1-2GB during transcription
- Accuracy: High for clear audio in supported languages

---

### 3. ✅ Database Future

**Decision:** **SQLite for MVP, evaluate PostgreSQL only if multi-user needed**

**Rationale:**

- Single user = no concurrent write conflicts
- SQLite with WAL mode supports concurrent reads
- Zero configuration overhead
- Perfect for embedded systems (RPi)
- 500MB typical size << SQLite limits

**Configuration:**

```ruby
# config/database.yml
production:
  adapter: sqlite3
  database: db/production.sqlite3
  pool: 5
  timeout: 5000
  # WAL mode for better concurrency
  pragmas:
    journal_mode: wal
    synchronous: normal
    cache_size: 10000
```

**Migration Path (if needed):**

- Use `pgloader` or `taps` for SQLite → PostgreSQL
- Only migrate if multi-user support required
- Estimated effort: 1-2 days

**Status:** SQLite locked for MVP

---

### 4. ✅ Authentication Level

**Decision:** **Minimal token-based auth for MVP, optional Devise later**

**Rationale:**

- Single user on local network = low security risk
- Simple API token sufficient for Telegram webhook validation
- Can add Devise if exposing to internet
- Reduces complexity for MVP

**Implementation:**

```ruby
# config/initializers/api_token.rb
class ApiTokenAuth
  def self.valid?(token)
    token == ENV['API_TOKEN']
  end
end

# app/controllers/api/base_controller.rb
class Api::BaseController < ApplicationController
  before_action :authenticate_token!

  private

  def authenticate_token!
    token = request.headers['Authorization']&.split(' ')&.last
    render json: { error: 'Unauthorized' }, status: 401 unless ApiTokenAuth.valid?(token)
  end
end
```

**Security Measures:**

- API token in environment variable (rotate every 90 days)
- HTTPS optional (local network assumption)
- Telegram webhook validates secret
- Input sanitization on all endpoints

**Future Enhancement:** Add Devise + session management if multi-user or internet exposure needed

---

### 5. ✅ Cloud Backup Policy

**Decision:** **Local backups primary, optional encrypted cloud backup**

**Rationale:**

- Privacy-first: all data local by default
- Cloud backup as user option (not mandatory)
- Encrypted backups preserve privacy
- User maintains control

**Backup Strategy:**

**Local Backups (Required):**

```bash
# Daily automated backups
0 2 * * * /app/scripts/backup.sh

# Retention: 7 daily, 4 weekly, 3 monthly
/backup/
├── daily/
│   ├── inbox-2026-02-12.tar.gz
│   ├── inbox-2026-02-11.tar.gz
│   └── ...
├── weekly/
│   └── inbox-week-07.tar.gz
└── monthly/
    └── inbox-2026-02.tar.gz
```

**Optional Cloud Backup (User Choice):**

```bash
# Encrypted upload to cloud storage
gpg --encrypt --recipient user@example.com backup.tar.gz
rclone copy backup.tar.gz.gpg remote:inbox-backups/

# Supported cloud providers (via rclone):
# - Google Drive
# - Dropbox
# - Nextcloud
# - S3 compatible
```

**Configuration:**

```bash
# .env
BACKUP_ENABLED=true
BACKUP_RETENTION_DAYS=7
BACKUP_ENCRYPTION_KEY=<gpg-key-id>
CLOUD_BACKUP_ENABLED=false  # User opt-in
CLOUD_BACKUP_PROVIDER=gdrive
```

**Privacy Guarantee:**

- Backups encrypted before upload
- Encryption key stays local
- Cloud provider sees only encrypted blobs
- User can disable cloud backup completely

**Status:** Local backups mandatory, cloud optional

---

## Open Questions & Pending Decisions

~~1. Ollama Model Selection~~ REMOVED (no longer using Ollama)
~~2. Whisper Model Size~~ REPLACED with Parakeet v3
~~3. Database Future~~ ✅ **RESOLVED:** SQLite for MVP
~~4. Authentication Level~~ ✅ **RESOLVED:** Minimal token-based
~~5. Cloud Backup~~ ✅ **RESOLVED:** Local + optional encrypted cloud

**All technical decisions finalized for MVP.**

---

## Constraints & Assumptions

### Technical Constraints

- Single user system (no multi-tenancy)
- Local network only (no internet exposure)
- Raspberry Pi 5 hardware limits
- SQLite concurrent write limits
- Memory: ~4-8GB available
- Storage: ~50GB allocated

### Assumptions

- User has Raspberry Pi 5 (or similar)
- Local network is trusted (no HTTPS required)
- Privacy is critical (no cloud services)
- User comfortable with Docker
- Audio transcription via Parakeet v3 (25 languages, auto-detect)
- Telegram bot for mobile capture

---

## Project Timeline

| Phase       | Duration | Focus                         | Status         |
| ----------- | -------- | ----------------------------- | -------------- |
| **Phase 0** | Week 1   | Bootstrap, setup, database    | ⏳ Planning    |
| **Phase 1** | Week 1-2 | Rails API, models, testing    | 📋 Not Started |
| **Phase 2** | Week 2-3 | Web editor, UI/UX             | 📋 Not Started |
| **Phase 3** | Week 3-4 | Telegram, Parakeet v3 transcription | ✅ Done |
| **Phase 4** | Week 4+  | Deployment, monitoring, docs  | 📋 Not Started |

**Total Timeline:** 4-5 weeks to MVP

---

## Success Criteria (MVP)

- ✅ System runs stable on RPi 5 (<20% CPU)
- ✅ Web interface responsive on mobile
- ✅ Telegram bot captures all message types
- ✅ Audio transcription accurate (Russian)
- ✅ Page load <500ms
- ✅ DB queries <100ms
- ✅ All features working offline
- ✅ Documentation complete
- ✅ Tests passing (80%+ coverage)
- ✅ Zero external dependencies

---

## Installed Skills (11 total)

**Project Management:**

- `project-creator` — Documentation scaffolding
- `changelog` — Keep a Changelog format
- `commits` — Conventional Commits
- `skill-master` — Skills authoring

**Development:**

- `telegram` — Telegram Bot API, aiogram 3
- `makefile` — Build automation
- `vite` — Frontend tooling
- `vitest` — Testing framework
- `react-testing-library` — Component testing

**Communication:**

- `social-writer` — Social media content
- `ask-questions-if-underspecified` — Requirements clarification

---

## Next Milestones

1. **Complete Phase 3** — Finalize architecture validation
2. **Create User Stories (Phase 4)** — Break down Features into stories
3. **Initialize OpenSpec (Phase 5)** — Set up planning workflow
4. **Begin Story #1** — Project setup & baseline
5. **Deploy baseline to RPi** — Verify infrastructure

---

## References

- [about.md](about.md) — Full project vision and features
- [specs.md](specs.md) — Technology versions and constraints
- [architecture.md](architecture.md) — Detailed system architecture
- [INIT.md](INIT.md) — Initialization checklist
- [stories/stories.md](stories/stories.md) — User stories

---

## Document Ownership

- **Created:** 2026-02-12
- **Owner:** Creator Agent (relief-pilot)
- **Last Updated:** 2026-02-12
- **Status:** Living document (updates ongoing)
