## Tasks

### Group 1: Event publishing infrastructure
- [x] 1.1 Create `app/models/concerns/domain_events.rb` concern with `after_commit` hooks publishing events via `ActiveSupport::Notifications.instrument`
- [x] 1.2 Event payload: `{ model_class:, model_id:, action:, changes:, timestamp: }`
- [x] 1.3 Event names follow `{model}.{action}` convention: `document.created`, `document.updated`, `document.deleted`, `task.created`, `task.completed`, `task.uncompleted`

### Group 2: Subscriber infrastructure
- [x] 2.1 Create `app/subscribers/base_subscriber.rb` with `subscribe(event_name)` class method
- [x] 2.2 Error isolation: rescue subscriber errors, log at ERROR level, continue other subscribers
- [x] 2.3 Create `config/initializers/event_subscribers.rb` to register all subscribers at boot

### Group 3: Migrate wiki-link extraction
- [x] 3.1 Create `app/subscribers/wiki_link_extraction_subscriber.rb` subscribing to `document.created` and `document.updated`
- [x] 3.2 Subscriber calls `DocumentLinkExtractor.new(document).extract_and_save`
- [x] 3.3 Remove `after_save :extract_wiki_links` callback from `Document` model
- [x] 3.4 Register subscriber in initializer

### Group 4: Include DomainEvents in models
- [x] 4.1 Include `DomainEvents` concern in `Document` model
- [x] 4.2 Include `DomainEvents` concern in `Task` model
- [x] 4.3 Add `task.completed` / `task.uncompleted` events in `Task#complete!` and `Task#uncomplete!` methods

### Group 5: Tests
- [x] 5.1 Test `DomainEvents` concern publishes events on create/update/destroy
- [x] 5.2 Test `WikiLinkExtractionSubscriber` extracts links when `document.created` event fires
- [x] 5.3 Test subscriber error isolation — one subscriber failing doesn't affect others
- [x] 5.4 Test event payload contains expected keys
- [x] 5.5 Regression: verify wiki-links are still extracted correctly after callback migration
