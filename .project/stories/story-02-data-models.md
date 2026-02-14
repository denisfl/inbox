# Story 2: Core Data Models & Database Setup

**Priority:** P0 (Critical)  
**Complexity:** High  
**Estimated Effort:** 3-4 days  
**Dependencies:** Story 1  
**Status:** Blocked (waiting for Story 1)

---

## User Story

As a developer, I want the core data models (Document, Block, Tag) implemented so that we can store and retrieve notes.

---

## Acceptance Criteria

### ✅ Database Configuration

- [ ] SQLite configured with WAL mode in `database.yml`
- [ ] Connection pool size: 5
- [ ] Timeout: 5000ms
- [ ] Pragmas configured:
  ```yaml
  pragmas:
    journal_mode: wal
    synchronous: normal
    cache_size: 10000
  ```

### ✅ Document Model

- [ ] Migration created: `create_documents`
- [ ] Schema:
  ```ruby
  create_table :documents do |t|
    t.string :title, null: false
    t.string :slug, null: false, index: { unique: true }
    t.string :source, default: 'web' # web, telegram, import
    t.string :category
    t.integer :priority
    t.timestamps
  end
  ```
- [ ] Model validations:
  - `validates :title, presence: true, length: { maximum: 255 }`
  - `validates :slug, presence: true, uniqueness: true`
  - `validates :source, inclusion: { in: %w[web telegram import] }`
- [ ] Associations:
  - `has_many :blocks, dependent: :destroy`
  - `has_and_belongs_to_many :tags`
- [ ] Callbacks:
  - `before_validation :generate_slug` (if blank)
- [ ] Scopes:
  - `scope :recent, -> { order(created_at: :desc) }`
  - `scope :by_source, ->(source) { where(source: source) }`

### ✅ Block Model (Polymorphic)

- [ ] Migration created: `create_blocks`
- [ ] Schema:
  ```ruby
  create_table :blocks do |t|
    t.references :document, null: false, foreign_key: true
    t.string :type, null: false # STI for block types
    t.integer :position, null: false
    t.json :data # Block-specific data
    t.timestamps
  end
  add_index :blocks, [:document_id, :position]
  ```
- [ ] Base Block model:
  ```ruby
  class Block < ApplicationRecord
    belongs_to :document
    validates :type, presence: true
    validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :data, presence: true

    # Auto-position on create
    before_create :set_position
  end
  ```

### ✅ Block Type Models (STI)

- [ ] TextBlock
  ```ruby
  # data: { text: "..." }
  validates :data, presence: true
  validate :text_present
  ```
- [ ] HeadingBlock
  ```ruby
  # data: { text: "...", level: 1-3 }
  validates :data, presence: true
  validate :text_and_level_present
  ```
- [ ] TodoBlock
  ```ruby
  # data: { text: "...", completed: false }
  validates :data, presence: true
  validate :text_and_completed_present
  ```
- [ ] CodeBlock
  ```ruby
  # data: { code: "...", language: "ruby" }
  validates :data, presence: true
  validate :code_present
  ```
- [ ] QuoteBlock
  ```ruby
  # data: { text: "...", author: "..." }
  validates :data, presence: true
  validate :text_present
  ```
- [ ] ImageBlock
  ```ruby
  # data: { url: "...", caption: "..." }
  has_one_attached :image
  validates :data, presence: true
  ```
- [ ] LinkBlock
  ```ruby
  # data: { url: "...", title: "..." }
  validates :data, presence: true
  validate :url_present
  ```
- [ ] FileBlock
  ```ruby
  # data: { filename: "..." }
  has_one_attached :file
  validates :data, presence: true
  ```

### ✅ Tag Model

- [ ] Migration created: `create_tags`
- [ ] Schema:

  ```ruby
  create_table :tags do |t|
    t.string :name, null: false, index: { unique: true }
    t.integer :documents_count, default: 0
    t.timestamps
  end

  create_table :documents_tags, id: false do |t|
    t.belongs_to :document
    t.belongs_to :tag
  end
  add_index :documents_tags, [:document_id, :tag_id], unique: true
  ```

- [ ] Model validations:
  - `validates :name, presence: true, uniqueness: true`
- [ ] Associations:
  - `has_and_belongs_to_many :documents`

### ✅ Testing

- [ ] Document model tests (RSpec):
  - Validations
  - Associations
  - Slug generation
  - Scopes
- [ ] Block model tests:
  - Validations
  - Position auto-increment
  - Data structure validation
- [ ] Tag model tests:
  - Validations
  - Associations
- [ ] Factory definitions (FactoryBot):
  - Document factory
  - Block factories (all types)
  - Tag factory
- [ ] Code coverage: 80%+

---

## Technical Tasks

1. **Create Migrations**

   ```bash
   rails g migration CreateDocuments
   rails g migration CreateBlocks
   rails g migration CreateTags
   rails g migration CreateDocumentsTags
   ```

2. **Create Models**

   ```bash
   rails g model Document title:string slug:string source:string
   rails g model Block document:references type:string position:integer data:json
   rails g model Tag name:string documents_count:integer
   ```

3. **Configure STI**
   - Create block type classes in `app/models/blocks/`
   - Register block types in `Block::BLOCK_TYPES` constant

4. **Write Tests**

   ```bash
   rspec spec/models/document_spec.rb
   rspec spec/models/block_spec.rb
   rspec spec/models/tag_spec.rb
   ```

5. **Run Migrations**
   ```bash
   rails db:migrate
   rails db:migrate RAILS_ENV=test
   ```

---

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Migrations run successfully
- [ ] Models validated with data
- [ ] All tests passing (80%+ coverage)
- [ ] FactoryBot factories working
- [ ] Code reviewed
- [ ] Database schema documented

---

## Notes

- Use JSON column for block data (flexible schema)
- STI pattern allows easy block type extension
- Position management critical for drag-drop
- Slug generation uses `parameterize` on title
