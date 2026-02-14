# inbox

## Vision

A **personal note-taking system** running on Raspberry Pi with:

- Block-based editor (like Craft.do, Logseq)
- Design like Basecamp, Bear.app, Things
- Telegram bot integration for quick capture
- Local audio transcription (OpenAI Whisper)
- Simple, modern interface
- Complete privacy (no cloud)
- Single user

## Problem & Opportunity

### The Problem

**Personal knowledge management is fragmented:**

- Notes scattered across apps (Notes, Keep, Telegram, Email)
- No single source of truth
- Difficulty organizing thoughts
- Audio ideas lost before they're written down
- Dependence on cloud services for privacy concerns
- Complex note-taking apps (Notion, Obsidian) are overkill

### The Opportunity

**Build a lightweight, focused note-taking system** that:

- Captures ideas from multiple sources (web, Telegram, voice)
- Keeps everything private and local
- Provides modern, minimalist interface
- Requires no subscriptions or account creation
- Runs on affordable hardware (Raspberry Pi)
- Respects user data completely

## Goals

### Primary Goals

1. **Create a fully functional block-based note editor** accessible from any device on local network
2. **Integrate Telegram bot** for frictionless note capture (text, voice, files)
3. **Implement local audio transcription** using Whisper for voice notes
4. **Deploy on Raspberry Pi** with automatic backups and monitoring
5. **Provide modern, minimal UI** inspired by Craft.do and Logseq

### Success Criteria

- ✅ System runs stable on Raspberry Pi 5 with <20% CPU usage
- ✅ Web interface responsive on mobile browsers
- ✅ Telegram bot captures all message types (text, voice, PDF, images)
- ✅ Audio transcription accurate for Russian language
- ✅ Page load time <500ms
- ✅ Database responsive (<100ms queries)
- ✅ All features working offline/local network
- ✅ Documentation complete for self-hosting
- ✅ Tests passing (80%+ coverage)
- ✅ Zero external dependencies (no cloud services)

## Target Audience

**Primary User:**

- Software developer or knowledge worker
- Values privacy and local data ownership
- Comfortable with self-hosting
- Wants minimal, focused tool
- Uses both desktop and mobile
- Appreciates modern UI/UX

**Secondary Users:**

- Anyone wanting privacy-first note-taking
- Users of Craft.do, Logseq, Obsidian
- People uncomfortable with cloud storage
- Developers needing simple documentation system

## Value Proposition

| Aspect          | Value                                   |
| --------------- | --------------------------------------- |
| **Privacy**     | 100% local, no cloud, no tracking       |
| **Simplicity**  | Minimal, distraction-free interface     |
| **Capture**     | Multiple sources (web, Telegram, voice) |
| **Cost**        | One-time hardware, no subscriptions     |
| **Flexibility** | Open source, fully customizable         |
| **Speed**       | Fast, responsive, runs on RPi           |
| **Ownership**   | Complete data ownership                 |

## Features & Capabilities

### Core Features (MVP)

**Web Editor:**

- Block-based document editor
- Multiple block types (Text, Heading, Todo, Image, Code, Quote, Link, File)
- Drag-drop block reordering
- Keyboard shortcuts (Cmd+Enter for new block)
- Auto-save functionality
- Tag/category system
- Full-text search
- Responsive design for mobile

**Telegram Integration:**

- Telegram bot that creates notes from messages
- Text → Document with TextBlock
- Voice messages → Auto-transcribed with Whisper
- PDF files → Parsed and extracted
- Images → DocumentWithImageBlock
- File attachments → Document with FileBlock

**Local Audio Processing:**

- OpenAI Whisper integration (local, no API calls)
- Automatic transcription of voice messages
- Russian language support
- Background processing with Sidekiq

**Data Management:**

- SQLite database (no external DB needed)
- Automatic daily backups
- Export to Markdown/PDF
- Import from Markdown

### Future Features

- Advanced search (filters, tags, date range)
- Nested documents/folders
- Collaborative features (later)
- Mobile app (iOS/Android)
- Browser extension for web capture
- Sharing links (time-limited, password-protected)
- Dark mode / Light mode themes
- Custom fonts and styling
- Table blocks
- Database blocks (simple relations)
- Templates for note types
- Reminders and scheduling
- Integration with other services (if needed)

## Scope Boundaries

### In Scope

**Phase 0-4 (4-5 weeks):**

- ✅ Rails 8 backend with REST API
- ✅ Block-based data model
- ✅ Web interface (Stimulus JS or Vanilla JS)
- ✅ Telegram bot with webhook
- ✅ Audio transcription (Whisper)
- ✅ SQLite database
- ✅ Deployment on Raspberry Pi
- ✅ Basic testing (80%+ coverage)
- ✅ Documentation for setup/development

### Out of Scope

**Not included in MVP:**

- ❌ Cloud synchronization
- ❌ Collaborative editing
- ❌ Mobile apps (web responsive only)
- ❌ Advanced AI features (search, summaries)
- ❌ Multi-user support
- ❌ Commercial hosting
- ❌ API for third parties
- ❌ Real-time collaboration
- ❌ End-to-end encryption (local network assumption)
- ❌ Video transcription
- ❌ Handwriting recognition

## Project Type

**Template**: NotesVault (Personal Note-Taking System)

## Technical Components

- **Frontend**: Yes (Stimulus JS / Hotwire - no React required)
- **Backend**: Yes (Rails 8, SQLite, Sidekiq)
- **Database**: Yes (SQLite3)
- **Authentication**: Minimal (Single user, optional token)
- **External APIs**: Telegram Bot API (webhook-based)
- **Audio Processing**: OpenAI Whisper (local, no API key)
- **Deployment**: Raspberry Pi 5, systemd services
- **Queue System**: Sidekiq + Redis
- **File Storage**: ActiveStorage (local disk)

## Technology Stack Summary

| Layer         | Technology      | Reason                                      |
| ------------- | --------------- | ------------------------------------------- |
| **Framework** | Rails 8         | Full-featured, rapid development            |
| **Language**  | Ruby 3.3        | Productive, readable code                   |
| **Database**  | SQLite          | Zero-config, perfect for single user        |
| **Frontend**  | Stimulus JS     | Lightweight, no build process, Rails-native |
| **Queue**     | Sidekiq + Redis | Reliable background jobs                    |
| **Audio**     | OpenAI Whisper  | Local, no API calls, accurate               |
| **Server**    | Puma            | Built-in, reliable                          |
| **DevOps**    | systemd on RPi  | Native, proven, simple                      |

## Project Timeline

| Phase       | Duration | Focus                         | Owner           |
| ----------- | -------- | ----------------------------- | --------------- |
| **Phase 0** | Week 1   | Bootstrap, setup, database    | Creator         |
| **Phase 1** | Week 1-2 | Rails API, models, testing    | Backend Dev     |
| **Phase 2** | Week 2-3 | Web editor, UI/UX             | Frontend Dev    |
| **Phase 3** | Week 3-4 | Telegram, Whisper integration | Integration Dev |
| **Phase 4** | Week 4+  | Deployment, monitoring, docs  | DevOps          |

**Total Timeline:** 4-5 weeks to MVP

## Key Decisions

1. **Single user by design** - Simplifies auth, removes complexity
2. **SQLite not PostgreSQL** - Sufficient for single user, zero setup
3. **Local Whisper not cloud API** - Privacy first, no cost, no API key
4. **Stimulus not React** - Keep it simple, Rails-native, fast dev
5. **Raspberry Pi target** - Affordable, runs at home, good enough
6. **Open source** - Full transparency, community contributions possible

## Risk Assessment

| Risk                 | Impact | Probability | Mitigation                             |
| -------------------- | ------ | ----------- | -------------------------------------- |
| Whisper slow on RPi  | Medium | Medium      | Use tiny model, optimize               |
| SQLite lock issues   | Low    | Low         | Increase timeout, careful query design |
| Telegram API changes | Low    | Low         | Keep API client updated                |
| Storage fill up      | Low    | Low         | Automatic cleanup, external backups    |

## Success Metrics (Month 1 Post-Launch)

- ✅ System stable (99%+ uptime)
- ✅ <5 reported bugs
- ✅ Users actively capturing notes daily
- ✅ Positive feedback on UI/UX
- ✅ All features working as intended
- ✅ Documentation helpful for self-hosting

## Next Steps (For Creator Agent)

1. Read this document fully
2. Read `.project/about.md` for detailed overview
3. Read `AGENTS.md` for team structure
4. Begin Phase 0 following `INIT.md` checklist
5. Report daily status to `.project/project-context.md`

---

## Document Ownership

- **Created:** [Date]
- **Owner:** Creator Agent
- **Last Updated:** [Date]
- **Status:** Ready for Phase 0 initialization

---

## References

- `.project/about.md` - Full project description
- `.project/specs.md` - Technical specifications
- `AGENTS.md` - Team and roles
- `INIT.md` - Setup checklist
- `BLOCKS_ARCHITECTURE.md` - System design
