## Context

Current code has business logic in models (callbacks) and controllers (inline operations). TelegramMessageHandler already lives in `app/services/` but doesn't follow a consistent pattern. DocumentLinkExtractor is a good example of service object design but lacks a result type.

## Goals / Non-Goals

**Goals:**

- Establish `ApplicationService` and `ServiceResult` patterns
- Extract document CRUD and search into services
- Make existing services callable from any entry point (web, API, Telegram, MCP)

**Non-Goals:**

- Extract ALL logic at once (incremental — start with documents)
- Move model validations to services (validations stay in models)
- Change external behavior (pure internal refactoring)

## Decisions

### 1. Lightweight ServiceResult over gem

**Choice**: Simple Ruby struct, not a gem like `dry-monads`.
**Rationale**: Minimal overhead, no new dependency. Single-user app doesn't need monadic composition.

### 2. Incremental extraction

**Choice**: Start with document services only. AI, integrations, review services come later.
**Rationale**: Documents are the most-used domain with the most entry points (web, API, Telegram). Prove the pattern first.

### 3. Services receive explicit params, not request objects

**Choice**: Services take keyword arguments, not `params` hash or request objects.
**Rationale**: Decouples services from HTTP layer. Same service works from controller, job, or CLI.

## Risks / Trade-offs

- **[Risk] Regressions during extraction** → Cover with tests before refactoring. Run full suite after each extraction.
- **[Trade-off] Duplication during transition** → Some controller logic will temporarily coexist with service logic until fully migrated.
