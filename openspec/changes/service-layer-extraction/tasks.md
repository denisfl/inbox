## 1. Base Infrastructure

- [ ] 1.1 Create `app/services/service_result.rb` with `success?`, `payload`, `errors` attributes and `.success` / `.failure` factory methods
- [ ] 1.2 Create `app/services/application_service.rb` with `.call` class method pattern
- [ ] 1.3 Unit tests for `ServiceResult` and `ApplicationService`

## 2. Document Services

- [ ] 2.1 Create `app/services/documents/create_service.rb` — accepts title, body, document_type, status, source
- [ ] 2.2 Extract document creation logic from `DocumentsController#create` into service
- [ ] 2.3 Extract document creation logic from `TelegramMessageHandler` into same service
- [ ] 2.4 Create `app/services/documents/search_service.rb` — accepts query, filters, scope, pagination
- [ ] 2.5 Extract search logic from `DocumentsController#index` into search service
- [ ] 2.6 Update `DocumentsController` to use `Documents::CreateService` and `Documents::SearchService`
- [ ] 2.7 Update `TelegramMessageHandler` to use `Documents::CreateService`

## 3. Existing Service Alignment

- [ ] 3.1 Update `DocumentLinkExtractor` to return `ServiceResult`
- [ ] 3.2 Update `GoogleCalendarService` methods to return `ServiceResult`

## 4. Tests

- [ ] 4.1 Unit tests for `Documents::CreateService` (success, validation failure, all sources)
- [ ] 4.2 Unit tests for `Documents::SearchService` (query, filters, empty results)
- [ ] 4.3 Verify all existing controller and request specs still pass
- [ ] 4.4 Verify all existing Telegram handler specs still pass
