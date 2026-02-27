## ADDED Requirements

### Requirement: Evening digest delivered via Telegram
At the configured evening time (default: 20:00), the system SHALL send a digest of the day's news to the user via Telegram.

#### Scenario: Digest contains today's news
- **GIVEN** news articles were fetched during the day
- **WHEN** `SendNewsDigestJob` runs at 20:00
- **THEN** the Telegram message SHALL contain content from all documents with `source: 'news'` created since midnight today

#### Scenario: Digest is summarized by Ollama
- **GIVEN** Ollama is available
- **WHEN** `SendNewsDigestJob` runs
- **THEN** it SHALL call Ollama to generate a concise summary (3–5 sentences, in Russian)
- **AND** the Telegram message SHALL contain the summary grouped by feed tag

#### Scenario: Fallback to title list if Ollama fails
- **GIVEN** Ollama is unavailable or returns an error
- **WHEN** `SendNewsDigestJob` runs
- **THEN** the Telegram message SHALL contain a plain bullet list of article titles (no summary)
- **AND** the digest SHALL still be sent

#### Scenario: No news today — no message sent
- **GIVEN** no news documents were created today (e.g., all feeds were empty)
- **WHEN** `SendNewsDigestJob` runs
- **THEN** no Telegram message SHALL be sent

### Requirement: Digest scheduled automatically
- **WHEN** the Rails application starts in production
- **THEN** `FetchNewsJob` SHALL be scheduled to run at 02:00 daily
- **AND** `SendNewsDigestJob` SHALL be scheduled to run at 20:00 daily
- **AND** both jobs SHALL be registered in `config/recurring.yml`
