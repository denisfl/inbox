## Tasks

### Group 1: AppConfig module

- [ ] 1.1 Create `lib/app_config.rb` with `AppConfig` module
- [ ] 1.2 Implement `setting` DSL macro for declaring variables with name, env key, type, default, and required flag
- [ ] 1.3 Implement type coercion: `:string`, `:integer`, `:boolean`, `:url`
- [ ] 1.4 Implement `validate!` method that collects all missing required vars and raises `AppConfig::ConfigError` with full list

### Group 2: Variable definitions

- [ ] 2.1 Define REQUIRED settings: `telegram_bot_token`, `telegram_allowed_user_id`, `web_password`, `secret_key_base` (production only)
- [ ] 2.2 Define OPTIONAL settings: `transcriber_url` (default `http://transcriber:5000`), `transcriber_language` (default nil), `api_token` (default `development_token` in dev), `api_rate_limit` (default 60), `google_calendar_ids` (default `primary`)
- [ ] 2.3 Define CONDITIONAL settings: `google_client_id`, `google_client_secret`, `google_refresh_token` (required if Google Calendar sync is used)

### Group 3: Rails initializer

- [ ] 3.1 Create `config/initializers/app_config.rb` that requires and calls `AppConfig.validate!`
- [ ] 3.2 In production: raise on missing required vars (prevents boot)
- [ ] 3.3 In development/test: log warnings for missing optional vars, skip required validation for test env

### Group 4: Service migration

- [ ] 4.1 Update `TelegramMessageHandler` to use `AppConfig.telegram_bot_token`
- [ ] 4.2 Update `TranscribeAudioJob` to use `AppConfig.transcriber_url` and `AppConfig.transcriber_language`
- [ ] 4.3 Update `Api::BaseController` to use `AppConfig.api_token`
- [ ] 4.4 Update `Api::TelegramController` to use `AppConfig.telegram_webhook_secret_token` and `AppConfig.telegram_allowed_user_id`
- [ ] 4.5 Update `ApplicationController` to use `AppConfig.web_password`
- [ ] 4.6 Update `GoogleCalendarService` to use `AppConfig.google_calendar_ids`

### Group 5: Documentation

- [ ] 5.1 Rewrite `.env.example` with all variables grouped by domain, with inline comments for purpose, requirement level, and defaults
- [ ] 5.2 Update README environment section to reference `AppConfig`

### Group 6: Tests

- [ ] 6.1 Unit tests for `AppConfig.validate!` — missing required raises, present passes
- [ ] 6.2 Unit tests for type coercion — integer, boolean, string, URL
- [ ] 6.3 Unit tests for default values used when ENV not set
- [ ] 6.4 Integration test: app boots with valid config, fails with missing required var
