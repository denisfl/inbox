## Why

Environment configuration is scattered across the codebase — each service reads its own ENV vars with inconsistent defaults and no validation. Missing a critical variable (e.g., `TELEGRAM_BOT_TOKEN`) causes a runtime error deep in the call stack rather than a clear boot-time failure. There's no `.env.example` reflecting the actual required variables, and no documentation of which are required vs optional.

## What Changes

- New `AppConfig` module that validates all ENV variables at boot time
- Categorization of variables: REQUIRED (fail if missing) vs OPTIONAL (use defaults)
- Type coercion (integer, boolean, URL) with meaningful error messages
- Structured `.env.example` with every variable documented
- Rails initializer that runs validation and fails fast on missing required vars

## Capabilities

### New Capabilities

- `env-config-validation`: Centralized environment configuration with boot-time validation, type coercion, and structured documentation
- `env-documentation`: Complete `.env.example` with inline documentation for all variables

### Modified Capabilities

<!-- Services will be updated to read from AppConfig instead of raw ENV -->

## Impact

- **New files**: `app/config/app_config.rb` (or `lib/app_config.rb`), `config/initializers/app_config.rb`
- **Modified files**: `.env.example` (comprehensive update), services reading ENV vars
- **Dependencies**: None (pure Ruby implementation)
