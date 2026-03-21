## Context

Currently, one `after_save` callback exists in `Document` model: `extract_wiki_links`. As more features are added (search indexing, tag sync, notifications), callbacks will accumulate. Rails' `ActiveSupport::Notifications` is the standard built-in event bus — zero dependencies, well-documented, and composable.

## Decisions

### 1. `DomainEvents` concern for models
**Rationale**: A concern included in models that replaces `after_commit` callbacks with event publishing. Uses `after_commit` (not `after_save`) to ensure events only fire after successful transaction.

```ruby
# app/models/concerns/domain_events.rb
module DomainEvents
  extend ActiveSupport::Concern

  included do
    after_commit :publish_created_event, on: :create
    after_commit :publish_updated_event, on: :update
    after_commit :publish_deleted_event, on: :destroy
  end
end
```

**Event names**: `{model}.{action}` format — e.g., `document.created`, `task.completed`.

### 2. Subscriber base class with error isolation
**Rationale**: Each subscriber is a plain Ruby class with a `call(event)` method. A base class wraps execution in error handling — if one subscriber fails, others continue. Errors are logged at ERROR level.

```ruby
# app/subscribers/base_subscriber.rb
class BaseSubscriber
  def self.subscribe(event_name)
    ActiveSupport::Notifications.subscribe(event_name) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      new.call(event)
    rescue => e
      Rails.logger.error("Subscriber #{name} failed: #{e.message}")
    end
  end
end
```

### 3. First migration: `extract_wiki_links` → `WikiLinkExtractionSubscriber`
**Rationale**: The existing `after_save :extract_wiki_links` in Document is the only callback to migrate. The subscriber listens to `document.created` and `document.updated` and calls `DocumentLinkExtractor`.

### 4. Registration in initializer
**Rationale**: `config/initializers/event_subscribers.rb` registers all subscribers at boot. Clear, explicit, and easy to audit.

### 5. Synchronous execution (for now)
**Rationale**: `ActiveSupport::Notifications` is synchronous by default. For the wiki-link extraction use case, synchronous is correct (links should be available immediately after save). Future subscribers that are expensive can enqueue background jobs.

## Risks

1. **Subscriber ordering**: No guaranteed execution order for multiple subscribers on the same event. Mitigate by designing subscribers to be independent (no cross-subscriber dependencies).
2. **Test complexity**: Tests must verify events are published and subscribers react. Create test helpers like `assert_event_published(:document.created)`.
3. **Performance**: Synchronous subscribers add latency to save operations. Monitor and move expensive subscribers to async jobs if needed.

## Implementation order

1. Create `DomainEvents` concern with event publishing
2. Create `BaseSubscriber` class
3. Create `WikiLinkExtractionSubscriber`
4. Create initializer for subscriber registration
5. Include `DomainEvents` in Document and Task models
6. Remove `after_save :extract_wiki_links` from Document
7. Add tests for event publishing and subscriber execution
