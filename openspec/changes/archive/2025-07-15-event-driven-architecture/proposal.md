## Why

Side effects in models (e.g., `after_save :extract_wiki_links` in Document) tightly couple models to secondary behaviors. As the app grows, more callbacks will be needed (update search index, sync tags, notify via Telegram, update statistics). This creates a cascade of model callbacks that are hard to test, hard to order, and create hidden dependencies.

`ActiveSupport::Notifications` provides a built-in event bus that decouples event producers from consumers, making the system extensible without modifying core models.

## What Changes

- Define domain events (`document.created`, `document.updated`, `document.deleted`, `task.created`, `task.completed`)
- Migrate `after_save :extract_wiki_links` to an event subscriber
- Create event subscriber infrastructure for future hooks
- Instrument key model lifecycle events

## Capabilities

### New Capabilities
- `domain-events`: Event publishing infrastructure using `ActiveSupport::Notifications` for model lifecycle events
- `event-subscribers`: Subscriber pattern for reacting to domain events without model callbacks

### Modified Capabilities
<!-- Document model: after_save callback migrated to event subscriber -->

## Impact

- **New files**: `app/events/` directory with event publisher module, `app/subscribers/` directory with subscriber classes
- **Modified files**: `app/models/document.rb` (replace callback with event), `config/initializers/event_subscribers.rb`
- **Dependencies**: None (ActiveSupport::Notifications is built into Rails)
