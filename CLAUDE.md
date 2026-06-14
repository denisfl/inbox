# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes, followed by project-specific
instructions for **inbox-web**.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# Project: inbox-web

Privacy-first single-user note system. Rails 8.1 + SQLite, Stimulus/Tailwind front end,
Telegram bot capture, local voice transcription, optional cloud file storage. Runs on a
Raspberry Pi — no external services required.

## Running things

Native `bundle` on this machine is currently broken (Gemfile.lock pins gems that aren't
installed for the active Ruby). **Use Docker for anything that boots Rails:**

The dev stack lives in `compose.dev.yaml`. It is **not** a default Compose filename
(that's deliberate — `docker-compose.yml` is the production stack and must stay the
default), so always pass it with `-f`:

```bash
docker compose -f compose.dev.yaml up                              # web → http://localhost:3000
docker compose -f compose.dev.yaml run --rm web bundle exec rspec  # full test suite
docker compose -f compose.dev.yaml run --rm web bin/rubocop        # style
docker compose -f compose.dev.yaml run --rm web bin/rails console
```

`compose.dev.yaml` bind-mounts the source (edits are live) and keeps gems + `storage/`
(SQLite db + uploads) in named volumes. See `Dockerfile.dev`.

If the native toolchain is fixed, the same commands work without the `docker compose run`
prefix: `bin/dev`, `bundle exec rspec`, `bin/rubocop`, `bin/brakeman --no-pager`.

## Layout

- `app/models`, `app/controllers` — standard Rails. Notes are `Document` + `Block`; the
  editor is Lexxy (ActionText rich text). The `Api::Uploads` block routes are **deprecated**
  (their specs are skipped) — uploads now flow through ActionText/ActiveStorage.
- `app/services/storage_adapter/` — pluggable cloud backends (S3, Dropbox, GoogleDrive,
  OneDrive, Local). `StorageAdapter.build(provider, config)` instantiates one.
- `app/services/oauth_manager.rb` — OAuth dance + token refresh for Dropbox/Drive/OneDrive.
- `lib/active_storage/service/unified_storage_service.rb` — the ActiveStorage service.
- `whisper_service/` — separate Python transcription service (Parakeet v3).

## File storage — read before touching

`config.active_storage.service = :unified` in **both dev and prod**. Every upload/download
goes through `ActiveStorage::Service::UnifiedStorageService`, which at runtime:

1. Reads the active `StorageSetting` (one row, `active: true`).
2. If the provider is a cloud one, builds a `StorageAdapter` and delegates to it.
3. Otherwise (provider `local`, no setting, or a DB error) falls back to a local
   `DiskService` rooted at `storage/`.

Non-obvious gotchas that have bitten us:

- **The test suite does not exercise this service.** Test env uses `config.active_storage.service = :test`
  (a plain Disk service), so unified-only code paths (cloud delegation, the disk fallback,
  lazy class loading) are invisible to most specs. `spec/lib/unified_storage_service_spec.rb`
  is the one place that does — extend it when you change the service.
- ActiveStorage **lazily loads** `Service` subclasses; only services named in `storage.yml`
  get required. Since dev/prod configure only `:unified`, `DiskService` is **not** auto-loaded
  there — the file `require`s it explicitly. Don't remove that require.
- The disk fallback serves files via `ActiveStorage::DiskController`, which calls
  `path_for` on the service named in the signed key (`"unified"`). The unified service must
  define `path_for` (delegates to the disk service) or local downloads 500.
- Cloud blobs are served by redirecting to the adapter's temporary URL (`private_url`/
  `public_url` return `adapter.url`), not through the disk controller.

## Conventions

- Ruby/Rails app uses RSpec + FactoryBot (`spec/`). There is also a `test/` dir — RSpec is canonical.
- `StorageSetting#config_data` is JSON stored in an encrypted column; cloud tokens live there.
- When adding a storage provider: add an adapter under `app/services/storage_adapter/`,
  register it in `StorageAdapter::ADAPTER_CLASSES`, and (if OAuth) in `OAuthManager::PROVIDERS`.
