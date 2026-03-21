## Context

The codebase reads ENV variables in ~20 locations across controllers, services, jobs, and config files. Each access point has its own default logic (or none). Key variables: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_WEBHOOK_SECRET_TOKEN`, `TELEGRAM_ALLOWED_USER_ID`, `API_TOKEN`, `WEB_PASSWORD`, `TRANSCRIBER_URL`, `TRANSCRIBER_LANGUAGE`, `GOOGLE_CALENDAR_IDS`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`, `DATABASE_URL`, `SOLID_QUEUE_IN_PUMA`, `GIT_SHA`.

## Decisions

### 1. `AppConfig` as a plain Ruby module with frozen constants

**Rationale**: No gem dependencies. Module methods with memoization provide fast, typed access. Boot-time validation in a Rails initializer catches missing vars before any request.

**Structure**:

```ruby
# lib/app_config.rb
module AppConfig
  class ConfigError < StandardError; end

  REQUIRED = %i[telegram_bot_token telegram_allowed_user_id web_password].freeze

  def self.telegram_bot_token = ENV.fetch("TELEGRAM_BOT_TOKEN")
  def self.transcriber_url = ENV.fetch("TRANSCRIBER_URL", "http://transcriber:5000")
  def self.validate! # raises ConfigError listing all missing required vars
end
```

**Alternative rejected**: `dry-configurable` or `anyway_config` gems — add dependency for something achievable with ~50 lines of Ruby.

### 2. Three-tier variable classification

- **REQUIRED**: App cannot function without these. Missing → `ConfigError` at boot. Examples: `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USER_ID`, `WEB_PASSWORD`, `SECRET_KEY_BASE` (production only)
- **OPTIONAL with defaults**: Work without them, using sensible defaults. Examples: `TRANSCRIBER_URL` (default `http://transcriber:5000`), `TRANSCRIBER_LANGUAGE` (default `nil` = auto-detect), `API_RATE_LIMIT` (default `60`)
- **CONDITIONAL**: Required only in certain contexts. Example: `GOOGLE_CLIENT_ID` required only if Google Calendar sync is enabled

### 3. Type coercion via declarative DSL

**Rationale**: A simple `setting` macro handles string→type conversion:

```ruby
setting :api_rate_limit, env: "API_RATE_LIMIT", type: :integer, default: 60
setting :backup_enabled, env: "BACKUP_ENABLED", type: :boolean, default: false
```

### 4. Validation runs in `config/initializers/app_config.rb`

**Rationale**: Rails initializers run once at boot. In production, a missing variable halts startup immediately with a clear message listing ALL missing vars (not just the first one). In development/test, optionally warn instead of crash to ease local setup.

### 5. Gradual migration — not big-bang

**Rationale**: Replace `ENV[]` calls service-by-service. Start with the most critical paths (Telegram, Transcriber), then expand. Old `ENV[]` calls continue to work during migration.

## Risks

1. **Test environment**: Tests may not set all required ENV vars. Mitigate by skipping validation in test or providing test defaults.
2. **Docker Compose**: `docker-compose.yml` sets many ENVs — must stay in sync with `AppConfig`. Mitigate by documenting in `.env.example`.
3. **Circular dependency**: If `AppConfig` is loaded too early before Rails initializes. Mitigate by placing in `lib/` and requiring in initializer.

## Implementation order

1. Create `lib/app_config.rb` with module structure and validation logic
2. Create `config/initializers/app_config.rb` that calls `AppConfig.validate!`
3. Define all current ENV variables as settings (required/optional/conditional)
4. Update `.env.example` with comprehensive documentation
5. Migrate services one-by-one to use `AppConfig` methods
6. Add tests for validation behavior (missing required, type coercion, defaults)
