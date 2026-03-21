## Tasks

### Group 1: SimpleCov configuration

- [ ] 1.1 Add `simplecov` to Gemfile test group (if not present)
- [ ] 1.2 Create `spec/support/simplecov.rb` with `SimpleCov.start 'rails'`, minimum_coverage 80, coverage groups
- [ ] 1.3 Require SimpleCov at the top of `spec/rails_helper.rb` (before any other require)
- [ ] 1.4 Run full suite and verify coverage report generates in `coverage/`

### Group 2: Integration test — Telegram voice to document

- [ ] 2.1 Create `spec/integration/telegram_voice_to_document_spec.rb`
- [ ] 2.2 Stub Telegram file download, Transcriber API, and LLM classification
- [ ] 2.3 POST webhook payload → verify Document created with transcribed body

### Group 3: Integration test — Wiki-links

- [ ] 3.1 Create `spec/integration/wiki_links_spec.rb`
- [ ] 3.2 Create two documents, update first with `[[Second]]` in body
- [ ] 3.3 Verify rendered HTML has live wiki-link, `document_links` record exists

### Group 4: Integration test — API document CRUD

- [ ] 4.1 Create `spec/integration/api_document_crud_spec.rb`
- [ ] 4.2 Test full lifecycle: POST create → GET show → PATCH update → DELETE destroy
- [ ] 4.3 Verify database state after each operation

### Group 5: Integration test — Calendar sync and reminders

- [ ] 5.1 Create `spec/integration/calendar_sync_reminder_spec.rb`
- [ ] 5.2 Stub Google Calendar API responses
- [ ] 5.3 Run sync job → verify events created → run reminder job → verify Telegram notification sent

### Group 6: Integration test — Document search

- [ ] 6.1 Create `spec/integration/document_search_spec.rb`
- [ ] 6.2 Create document with known content → search via API → verify found in results

### Group 7: CI pipeline

- [ ] 7.1 Create `.github/workflows/ci.yml` with Ruby 3.3, SQLite, bundle install, rspec
- [ ] 7.2 Configure coverage artifact upload
- [ ] 7.3 Set CI to run on push to main and pull requests

### Group 8: Documentation

- [ ] 8.1 Add test strategy section to README (how to run tests, coverage targets)
- [ ] 8.2 Document integration test conventions in `spec/integration/README.md`
