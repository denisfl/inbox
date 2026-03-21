## Why

As functionality grows (wiki-links, status workflow, embeddings, MCP agents), business logic accumulates in models and controllers. This makes testing harder, reuse across entry points (web, API, Telegram, MCP) impossible, and increases coupling. A service layer provides a single place for business logic that all entry points can share.

## What Changes

- Extract existing business logic from controllers and models into service objects in `app/services/`
- Organize services by domain: `documents/`, `ai/`, `integrations/`, `review/`
- Each service receives explicit parameters (no implicit `current_user` or controller context)
- Services return result objects (`ServiceResult` with `success?`, `payload`, `errors`)
- Controllers become thin: params → service → response

## Capabilities

### New Capabilities

- `service-result-pattern`: Base `ServiceResult` class and `ApplicationService` pattern for all service objects
- `document-services`: Extracted document creation, search, and link extraction services

### Modified Capabilities

<!-- No existing spec-level capability changes — this is a refactoring that preserves behavior -->

## Impact

- **New files**: `app/services/application_service.rb`, `app/services/service_result.rb`, `app/services/documents/create_service.rb`, `app/services/documents/search_service.rb`
- **Modified files**: `DocumentsController`, `DashboardController`, `TelegramMessageHandler` — delegate to services instead of inline logic
- **Dependencies**: None
- **Risk**: Large refactoring scope. Must maintain existing behavior exactly.
