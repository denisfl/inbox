# Inbox

A privacy-first personal note-taking system with Telegram bot integration, voice transcription, and calendar sync. Runs on a Raspberry Pi — no cloud required.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Why

We live in an interesting time when producing code has become incredibly cheap. You can vibe-code any solution and solve your problem. This project is my personal answer to the shortcomings of modern information capture and storage systems. My current setup is a home server running on a Raspberry Pi where I keep all my notes. I have tried plenty of tools — Evernote, Obsidian, and others. They are great products, but I wanted more flexibility for my specific workflows. So I vibe-coded my own. If it turns out to be useful for someone else, I will consider the world a tiny bit better.

## Features

- **Telegram Bot** -- capture notes, voice messages, photos, and files from Telegram
- **Voice Transcription** -- local audio-to-text via [Parakeet v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) (no cloud API, 25 languages)
- **Google Calendar Sync** -- import events and get reminders via Telegram
- **Tags** -- organize documents and tasks with a flexible tagging system
- **Tasks** -- simple task management with due dates
- **Markdown Editor** -- write and preview Markdown with live toggle
- **Search** -- full-text search across all documents
- **Privacy** -- everything stays on your hardware, single-user design

## Screenshots

|                  Dashboard                   |                  Documents                   |
| :------------------------------------------: | :------------------------------------------: |
| ![Dashboard](docs/screenshots/dashboard.png) | ![Documents](docs/screenshots/documents.png) |

|                Tasks                 |                  Calendar                  |
| :----------------------------------: | :----------------------------------------: |
| ![Tasks](docs/screenshots/tasks.png) | ![Calendar](docs/screenshots/calendar.png) |

## Tech Stack

| Component       | Technology                            |
| --------------- | ------------------------------------- |
| Backend         | Ruby on Rails 8.1                     |
| Database        | SQLite3                               |
| Frontend        | Stimulus.js, Tailwind CSS             |
| Asset Pipeline  | Propshaft, esbuild, cssbundling-rails |
| Background Jobs | SolidQueue / Sidekiq                  |
| Transcription   | Parakeet v3 / onnx-asr (Python)       |
| Containers      | Docker Compose                        |
| Testing         | RSpec, FactoryBot, SimpleCov          |

## Quick Start (Docker)

### Prerequisites

- Docker and Docker Compose
- A Telegram bot token (from [@BotFather](https://t.me/BotFather))

### 1. Clone and configure

```bash
git clone https://github.com/yourusername/inbox.git
cd inbox

# Create environment file
cp .env.example .env
```

Edit `.env` and fill in your values:

```dotenv
SECRET_KEY_BASE=$(openssl rand -hex 64)
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
TELEGRAM_BOT_NAME=your_bot_name
TELEGRAM_ALLOWED_USER_ID=your_telegram_user_id
TELEGRAM_WEBHOOK_URL=https://your-domain.com/api/telegram/webhook
```

> **Tip:** To find your Telegram user ID, send a message to [@userinfobot](https://t.me/userinfobot).

### 2. Set up Docker secrets

```bash
mkdir -p secrets
echo "your_bot_token" > secrets/telegram_bot_token
openssl rand -hex 32 > secrets/telegram_webhook_secret_token
chmod 600 secrets/*
```

### 3. Build and start

```bash
docker compose build
docker compose run --rm web bin/rails db:create db:migrate
docker compose up -d
```

### 4. Register Telegram webhook

```bash
BOT_TOKEN=$(cat secrets/telegram_bot_token)
SECRET_TOKEN=$(cat secrets/telegram_webhook_secret_token)

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\": \"https://your-domain.com/api/telegram/webhook\", \"secret_token\": \"${SECRET_TOKEN}\"}"
```

### 5. Open the app

Navigate to `http://localhost:3000` (or your domain if deployed).

## Development Setup

### Prerequisites

- Ruby 3.3+ (via [asdf](https://asdf-vm.com/), rbenv, or rvm)
- Node.js 22+
- pnpm
- SQLite3 3.43+

### Setup

```bash
# Install dependencies
bundle install
pnpm install

# Setup database
bin/rails db:create db:migrate db:seed

# Build assets
pnpm run build
pnpm run build:css

# Start development server
bin/dev
```

### Running Tests

```bash
bundle exec rspec              # Full test suite
bin/rubocop                    # Code style
bin/brakeman --no-pager        # Security scan
```

## Environment Variables

| Variable                   | Required | Description                                                    |
| -------------------------- | -------- | -------------------------------------------------------------- |
| `SECRET_KEY_BASE`          | Yes      | Rails secret key (generate with `openssl rand -hex 64`)        |
| `TELEGRAM_BOT_TOKEN`       | Yes      | Bot token from BotFather                                       |
| `TELEGRAM_BOT_NAME`        | Yes      | Bot username (without @)                                       |
| `TELEGRAM_ALLOWED_USER_ID` | Yes      | Your Telegram user ID                                          |
| `TELEGRAM_WEBHOOK_URL`     | Yes      | Public URL for webhook                                         |
| `API_TOKEN`                | No       | Token for API authentication                                   |
| `GIT_SHA`                  | No       | Git commit SHA, baked at build time for version tracking       |
| `TRANSCRIBER_URL`          | No       | Transcription service URL (default: `http://transcriber:5000`) |
| `TRANSCRIBER_LANGUAGE`     | No       | Force transcription language (default: auto-detect)            |
| `GOOGLE_CLIENT_ID`         | No       | For Google Calendar sync                                       |
| `GOOGLE_CLIENT_SECRET`     | No       | For Google Calendar sync                                       |
| `GOOGLE_REFRESH_TOKEN`     | No       | For Google Calendar sync                                       |
| `GOOGLE_CALENDAR_IDS`      | No       | Comma-separated calendar IDs (default: `primary`)              |

## How It Works

Inbox collects information from multiple sources, processes it in the background, and presents everything through a clean web interface.

```
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│    Telegram Bot      │   │   Google Calendar     │   │    Web Editor        │
│  text / voice / files│   │   OAuth / RPi sync   │   │  web / quick capture │
└─────────┬───────────┘   └─────────┬───────────┘   └─────────┬───────────┘
          │                         │                          │
          ▼                         ▼                          ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐
│      Webhook         │   │    GCal Sync Job     │   │   Rails Controller   │
│  POST /api/telegram  │   │   Sidekiq / cron     │   │   Form / Turbo       │
└─────────┬───────────┘   └─────────┬───────────┘   └─────────┬───────────┘
          │                         │                          │
          └────────────┬────────────┘──────────────────────────┘
                       ▼
          ┌───────────────────────┐
          │     SQLite Database    │
          │  documents · tasks     │
          │  calendar_events · tags │
          └───────────┬───────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌──────────────┐ ┌──────────┐ ┌──────────┐
│  Parakeet v3  │ │  Redis   │ │  Google   │
│ Transcription │ │  Cache   │ │ Cal API  │
│ (local, CPU)  │ │ + Queue  │ │ (OAuth)  │
└──────────────┘ └──────────┘ └──────────┘
```

### Data Flow

1. **Capture** -- Send a text message, voice note, photo, or file to your Telegram bot. Or type directly in the web editor.
2. **Process** -- Voice messages are transcribed locally by Parakeet v3 with automatic punctuation and capitalization. All messages are saved as notes.
3. **Store** -- Everything lands in SQLite as a document with Markdown content. Tasks get due dates and priorities. Calendar events sync from Google.
4. **Organize** — Tag documents and tasks. Pin important notes. Filter by source, tag, or date.
5. **Access** — Browse, search, and edit from any device through the web UI. Protected by HTTP Basic Auth over HTTPS.

## Deployment

For production deployment on a Raspberry Pi with Docker Compose, nginx, and WireGuard VPN, see the [Deployment Quickstart](.project/deployment-quickstart.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code style, and PR guidelines.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Support the project

If you find Inbox useful, consider supporting development via GitHub Sponsors.
