## Why

Inbox is the user's single attention center, but currently it only stores what the user explicitly sends. News from key sources accumulates elsewhere and requires manual monitoring. A nightly collection + evening digest would make Inbox the place where the day's information arrives automatically.

## What Changes

- A recurring job runs overnight to fetch articles from user-configured RSS/Atom feeds or web URLs
- News items are parsed, deduped, and stored as documents (source: `news`)
- At a configured time each evening, a digest document is assembled and sent to the user via Telegram
- Sources are configured in the admin/settings area or via a YAML config file

## Capabilities

### New Capabilities

- `news-source-fetching`: Recurring job (via SolidQueue recurring tasks) fetches content from configured RSS feeds and web sources. Each item saved as a document with source: `news`, tagged by feed name. Deduplicated by URL.
- `evening-digest`: At a scheduled time (e.g., 20:00), a digest job assembles all news documents from the current day, generates a summary via Ollama, and sends it to the user's Telegram chat as a structured message.

### New Components

- `FetchNewsJob` — fetches RSS/Atom feeds, parses items, saves as documents
- `SendNewsDigestJob` — triggered by recurring schedule; aggregates today's news docs, calls Ollama for summarization, sends Telegram message
- `config/news_sources.yml` — list of RSS URLs and labels
- `config/recurring.yml` update — add schedule for fetch (e.g., 02:00) and digest (e.g., 20:00)

## Impact

- **Dependencies**: `feedjira` gem (RSS/Atom parsing) or `nokogiri` for HTML scraping
- **Model**: Documents with `source: 'news'`, tagged by feed name; possibly `url` field on Document for deduplication
- **Ollama**: used for digest summarization (same instance, best-effort)
- **SolidQueue**: recurring tasks already supported via `config/recurring.yml`
- **Telegram**: existing bot token used to send digest to the user's `TELEGRAM_ALLOWED_USER_ID`
- **No new infrastructure** — runs within existing Rails + SolidQueue stack
