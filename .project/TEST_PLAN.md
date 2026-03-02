# Test Plan for Inbox Application

## Executive Summary

This document outlines a comprehensive testing strategy for the Inbox web application - a PWA note-taking system with Telegram integration, block-based editor, and advanced features.

---

## Application Architecture Analysis

### Core Components

1. **Models**:
   - `Document` - Main note entity with title, slug, metadata
   - `Block` - Content blocks (text, heading, todo, code, quote, image, file, link)
   - `Tag` - Tagging system
   - `DocumentTag` - Join table for many-to-many

2. **Controllers**:
   - `DocumentsController` - Main CRUD for documents
   - `Api::DocumentsController` - JSON API for documents
   - `Api::BlocksController` - Block CRUD operations
   - `Api::UploadsController` - File/image uploads

3. **Services**:
   - `TelegramMessageHandler` - Process incoming Telegram messages
   - PWA Service Worker - Offline caching and updates

4. **Frontend (Stimulus Controllers)**:
   - `document_editor` - Main editor with markdown, keyboard shortcuts, drag-n-drop
   - `keyboard` - Global vim-like shortcuts (g+n, g+s)
   - `audio_player` - Custom audio player with speed controls
   - `search` - Document search popup
   - `pwa` - Service worker management

---

## Test Coverage Targets

- **Models**: 100% (critical business logic)
- **Controllers**: 95% (API contracts)
- **Services**: 95% (external integrations)
- **System/Integration**: 80% (user workflows)
- **Overall Target**: 85%+

---

## Test Types & Strategy

### 1. Unit Tests (Models)

**Purpose**: Validate business logic, associations, validations, callbacks

**Coverage**:
- All model associations
- All validations (presence, format, numericality)
- Callbacks (auto-slug, position assignment)
- Scopes (ordered, by_type, by_source)
- Instance methods (content_hash, content_hash=)

### 2. Request/API Tests

**Purpose**: Validate API contracts, authentication, error handling

**Coverage**:
- CRUD operations for all resources
- Authorization (token-based API auth)
- Error responses (400, 404, 422, 500)
- JSON structure validation
- Edge cases (duplicate slugs, invalid data)

### 3. Service Tests

**Purpose**: Validate external integrations, message processing

**Coverage**:
- Telegram message handling (text, audio, images)
- File upload processing
- Voice transcription (Whisper service)

### 4. System/Integration Tests (Capybara)

**Purpose**: Validate end-to-end user workflows

**Coverage**:
- Document creation/editing/deletion
- Block operations (create, update, delete, reorder)
- Markdown shortcuts
- Keyboard navigation
- Search functionality
- File uploads
- PWA installation/updates

### 5. JavaScript/Stimulus Tests (Future)

**Purpose**: Validate frontend controllers

**Coverage**:
- Document editor behavior
- Keyboard shortcuts
- Audio player controls
- Search popup
- PWA updates

---

## Critical Test Scenarios

### Priority 1: Core Functionality

1. **Document Creation**
   - Create document with title
   - Auto-generate slug
   - Handle duplicate slugs (add timestamp)
   - Create with initial empty text block

2. **Block Management**
   - Create blocks of all types (text, heading, todo, code, quote, image, file, link)
   - Update block content
   - Delete blocks
   - Reorder blocks (drag-n-drop)
   - Auto-assign position when nil

3. **TODO Blocks** (Recently Fixed - CRITICAL)
   - Create TODO with Enter key
   - Multiple rapid TODO creation (no race condition)
   - Toggle checked state
   - Update TODO text
   - Cursor navigation

4. **Content Persistence**
   - content_hash= setter usage
   - JSON serialization/deserialization
   - Save indicators (saving/saved/error)

### Priority 2: User Experience

5. **Keyboard Shortcuts**
   - Vim-like shortcuts (g+n, g+s)
   - Work in contenteditable areas
   - Ignore in input/textarea
   - Escape closes search

6. **Markdown Shortcuts**
   - `# ` → heading
   - `- ` → list
   - `> ` → quote
   - ` ``` ` → code block
   - `[ ] ` → todo unchecked
   - `[x] ` → todo checked

7. **Search**
   - Full-text search in document titles/content
   - Filter by source (telegram, web)
   - Filter by type (text, voice, image)
   - Filter by tags

8. **File Handling**
   - Image upload and display
   - Audio file upload
   - Audio player controls (play/pause, speed, seek)
   - Download files

### Priority 3: Advanced Features

9. **PWA**
   - Service worker registration
   - Offline caching (cache-first for assets, network-first for data)
   - Update detection and banner
   - Version management (v2.1)

10. **Telegram Integration**
    - Text message → document
    - Voice message → transcription
    - Image → document with image block
    - Metadata extraction (source, type)

11. **Empty States**
    - No documents
    - No search results
    - No filter matches

12. **Performance**
    - Debounced autosave (300ms)
    - Optimistic UI updates
    - Lazy loading

---

## Test Data Strategy

### Factories (FactoryBot)

**Documents**:
```ruby
factory :document do
  title { Faker::Lorem.sentence }
  slug { title.parameterize }
  source { [:telegram, :web].sample }
  metadata { {} }
end
```

**Blocks**:
```ruby
factory :block do
  association :document
  block_type { Block::BLOCK_TYPES.sample }
  position { 0 }
  content { { text: Faker::Lorem.paragraph }.to_json }
  
  trait :text
  trait :heading
  trait :todo
  trait :code
  trait :quote
  trait :image
  trait :file
end
```

**Tags**:
```ruby
factory :tag do
  name { Faker::Lorem.word }
end
```

---

## Test Scenarios by Feature

### Feature: Document Creation

**Unit Tests**:
- ✅ Validates presence of title
- ✅ Generates slug from title
- ✅ Handles duplicate slugs with timestamp
- ✅ Creates with initial block
- ✅ Sets default source to 'web'

**Request Tests**:
- ✅ POST /api/documents creates document
- ✅ Returns 201 with correct JSON structure
- ✅ Handles validation errors (422)

**System Tests**:
- Create document via UI (click "New Note")
- Create document via /new route
- Create document via g+n shortcut
- Verify title autosave
- Verify initial block creation

### Feature: Block Operations

**Unit Tests**:
- ✅ Validates block_type inclusion
- ✅ Validates position numericality
- ✅ Auto-assigns position when nil
- ✅ content_hash getter/setter
- ✅ Ordered scope
- ✅ by_type scope

**Request Tests**:
- ✅ POST /api/documents/:id/blocks creates block
- ✅ PATCH /api/documents/:id/blocks/:id updates block
- ✅ DELETE /api/documents/:id/blocks/:id deletes block
- ✅ Handles nil position (auto-assign)
- ✅ Returns serialized block with attachments

**System Tests**:
- Create text block
- Create heading block
- Create TODO block with Enter
- **Rapid TODO creation (NO 500 error)**
- Toggle TODO checkbox
- Delete block
- Reorder blocks via drag-n-drop

### Feature: Keyboard Shortcuts

**Unit Tests**:
- N/A (JavaScript controller)

**System Tests**:
- Press g+n → redirect to /new
- Press g+s → open search popup
- Press Escape → close search
- Type in contenteditable → shortcuts work
- Type in input → shortcuts ignored
- Sequence timeout (1 second)

### Feature: Markdown Shortcuts

**System Tests**:
- Type `# ` → converts to heading
- Type `## ` → heading level 2
- Type `> ` → quote block
- Type `- ` → list (not implemented yet?)
- Type ` ``` ` → code block
- Type `[ ] ` → unchecked TODO
- Type `[x] ` → checked TODO

### Feature: Audio Player

**System Tests**:
- Upload audio file
- Click play → audio starts, icon changes to pause
- Click pause → audio pauses, icon changes to play
- Click progress bar → seeks to position
- Click speed button → cycles through 1.0x → 1.25x → 1.5x → 1.75x → 2.0x → 1.0x
- Time display updates during playback
- Download button works

### Feature: Search

**Request Tests**:
- GET /documents?q=keyword → returns matching documents
- GET /documents?source=telegram → filters by source
- GET /documents?type=voice → filters by type
- GET /documents?tag=work → filters by tag

**System Tests**:
- Press g+s → search popup opens
- Type query → results update (if live)
- Submit search → redirects to /documents?q=query
- Clear search → returns to all documents
- Empty state when no results

### Feature: Telegram Integration

**Service Tests**:
- Text message → creates document
- Voice message → creates document with audio block
- Image message → creates document with image block
- Extracts metadata (source: telegram, type: voice/image/text)
- Handles errors gracefully

**Integration Tests** (if Telegram bot available):
- Send text to bot
- Send voice to bot
- Send image to bot
- Verify documents created in DB

### Feature: PWA

**System Tests** (challenging - requires browser devtools):
- Service worker registers on page load
- Offline: cached pages load
- Offline: API requests fail gracefully
- Update available: banner shows
- Click Update → page reloads with new version
- Version bump (v2.1 → v2.2) triggers update

**Manual Tests**:
- Install PWA on mobile/desktop
- Use offline
- Receive update notification

---

## Test Environment Setup

### RSpec Configuration

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end
  
  config.before(:each) do
    DatabaseCleaner.start
  end
  
  config.after(:each) do
    DatabaseCleaner.clean
  end
  
  config.before(:each, type: :request) do
    host! "test.localhost"
  end
end
```

### System Test Setup (Capybara + Selenium)

```ruby
# spec/rails_helper.rb
require 'capybara/rails'
require 'capybara/rspec'

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')
  
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
Capybara.default_max_wait_time = 5
```

---

## Test Execution Plan

### Phase 1: Models (Week 1)
- Write/update all model specs
- Achieve 100% model coverage
- Fix validation tests (position now allow_nil)

### Phase 2: API/Controllers (Week 2)
- Write request specs for all API endpoints
- Test authentication/authorization
- Test error handling

### Phase 3: Services (Week 3)
- Test TelegramMessageHandler
- Mock external services (Whisper)

### Phase 4: System Tests (Week 4)
- Critical user workflows
- Keyboard/markdown shortcuts
- Audio player
- Search

### Phase 5: CI/CD Integration (Week 5)
- Add test suite to CI pipeline
- Set up code coverage reporting (SimpleCov)
- Fail build if coverage < 85%

---

## Known Issues to Test

### Recently Fixed (Must Verify)
1. ✅ **TODO Creation Race Condition**
   - Multiple rapid TODO creation caused database lock
   - Fixed by removing position from client-side payload
   - **Test**: Rapid Enter presses in TODO block

2. ✅ **Keyboard Shortcuts in Editor**
   - Shortcuts blocked in contenteditable areas
   - Fixed by removing contenteditable from ignore list
   - **Test**: Press g+n while editing document

3. ✅ **PWA Root Path Caching**
   - Root path cached, new documents not visible
   - Fixed with network-first strategy for /
   - **Test**: Create document, return to home (no cache)

4. ✅ **Duplicate Slug Handling**
   - Duplicate "Untitled" caused RecordInvalid
   - Fixed with timestamp suffix
   - **Test**: Create multiple untitled documents

---

## Test Maintenance

### Regular Updates
- Add tests for new features
- Update tests when fixing bugs
- Refactor tests to remove duplication

### Code Review Checklist
- [ ] All new features have tests
- [ ] Tests pass locally
- [ ] Tests pass in CI
- [ ] Coverage target met (85%+)
- [ ] No pending/skipped tests without explanation

---

## Tools & Dependencies

### Installed Gems
- `rspec-rails` ~> 7.0
- `factory_bot_rails` ~> 6.4
- `faker` ~> 3.2
- `capybara`
- `selenium-webdriver`
- `simplecov` (coverage reporting)
- `database_cleaner-active_record` ~> 2.2
- `shoulda-matchers` ~> 6.0

### Commands
```bash
# Run all tests
bin/test

# Run specific file
bundle exec rspec spec/models/document_spec.rb

# Run with coverage
COVERAGE=true bundle exec rspec

# Run system tests only
bundle exec rspec spec/system

# Run failed tests
bundle exec rspec --only-failures
```

---

## Appendix: Test Templates

### Model Test Template
```ruby
require 'rails_helper'

RSpec.describe ModelName, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:parent) }
    it { is_expected.to have_many(:children) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:field) }
  end

  describe 'scopes' do
    # scope tests
  end

  describe 'instance methods' do
    # method tests
  end
end
```

### Request Test Template
```ruby
require 'rails_helper'

RSpec.describe 'API Endpoint', type: :request do
  describe 'POST /api/resources' do
    let(:valid_params) { { resource: attributes_for(:resource) } }
    
    it 'creates resource' do
      expect {
        post '/api/resources', params: valid_params
      }.to change(Resource, :count).by(1)
      
      expect(response).to have_http_status(:created)
      expect(json_response).to include('id', 'name')
    end
    
    context 'with invalid params' do
      it 'returns 422' do
        post '/api/resources', params: { resource: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
```

### System Test Template
```ruby
require 'rails_helper'

RSpec.describe 'Feature Name', type: :system, js: true do
  before do
    driven_by(:headless_chrome)
  end

  it 'performs action' do
    visit root_path
    click_on 'Button'
    
    expect(page).to have_content('Expected Text')
  end
end
```

---

## Success Metrics

- [ ] 85%+ overall test coverage
- [ ] 100% model coverage
- [ ] All critical workflows tested
- [ ] CI green for all PRs
- [ ] No production bugs from untested code
- [ ] Test suite runs in < 5 minutes

---

**Version**: 1.0  
**Last Updated**: 2026-02-22  
**Status**: Draft → Ready for Implementation
