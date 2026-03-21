## Context

The project has 484 RSpec examples (0 failures, 35 pending) covering models, services, jobs, API requests, web requests, and helpers. However, no integration tests verify cross-component user journeys. SimpleCov is listed in the Gemfile but may not be configured with thresholds. No CI pipeline exists.

## Decisions

### 1. Integration specs in `spec/integration/` directory

**Rationale**: Separate from unit/request specs to signal they test cross-component flows. Each file covers one critical path. Uses full Rails environment (models, services, jobs, controllers) with external APIs stubbed via WebMock.

### 2. Five critical paths to test

1. **Telegram voice → document**: Webhook POST → ProcessTelegramUpdateJob → TelegramMessageHandler → TranscribeAudioJob → Document created with content
2. **Wiki-links → document links**: Create two documents, add wiki-link in body → verify rendered HTML has live link, verify `document_links` record exists
3. **API document CRUD**: Full lifecycle via API endpoints with token auth
4. **Calendar sync → reminders**: GoogleCalendarSyncJob creates events → SendEventReminderJob sends reminders
5. **Document search**: Create document → search via API → find it in results

### 3. SimpleCov with 80% line coverage minimum

**Rationale**: 80% is achievable given existing coverage and provides meaningful protection. Configure `SimpleCov.minimum_coverage 80` to fail the suite if coverage drops.

### 4. GitHub Actions CI pipeline

**Rationale**: `.github/workflows/ci.yml` running on push/PR. Docker-based to match production environment. Runs `bundle exec rspec` with SimpleCov. Uploads coverage artifact.

**Key constraint**: CI must set up SQLite and run without external services (Transcriber, Google Calendar) — all external calls are WebMock-stubbed.

## Risks

1. **Flaky integration tests**: Cross-component tests are inherently more fragile. Mitigate with deterministic stubs, no time-dependent assertions, and `DatabaseCleaner`.
2. **CI Docker complexity**: Running the Rails app in CI with SQLite may need specific setup. Mitigate with a simple `ruby:3.3` Docker image.
3. **Coverage threshold too aggressive**: If current coverage is below 80%, adding the threshold will immediately fail. Check actual coverage first and adjust.

## Implementation order

1. Configure SimpleCov with threshold and coverage groups
2. Write 5 integration spec files
3. Create GitHub Actions CI workflow
4. Verify coverage meets 80% threshold
5. Document test strategy in README
