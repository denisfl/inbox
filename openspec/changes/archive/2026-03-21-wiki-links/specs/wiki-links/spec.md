## ADDED Requirements

### Requirement: Document links storage

The system SHALL store directional links between documents in a `document_links` table with `source_document_id` and `target_document_id` foreign keys referencing `documents`. A unique index on `[source_document_id, target_document_id]` SHALL prevent duplicate links.

#### Scenario: Link record created when wiki-link exists

- **WHEN** Document A contains `[[Document B]]` in its body
- **THEN** a `DocumentLink` record exists with `source_document_id = A.id` and `target_document_id = B.id`

#### Scenario: Duplicate links prevented

- **WHEN** Document A references `[[Document B]]` twice in its body
- **THEN** only one `DocumentLink` record exists for that pair

#### Scenario: Links removed when reference removed

- **WHEN** Document A previously linked to Document B but the `[[Document B]]` text is removed and the document is saved
- **THEN** the `DocumentLink` record for that pair SHALL be deleted

#### Scenario: Cascading deletion

- **WHEN** a document is destroyed
- **THEN** all `DocumentLink` records where it is source or target SHALL be destroyed

### Requirement: Document model associations

The `Document` model SHALL have:

- `has_many :outgoing_links` (class: `DocumentLink`, FK: `source_document_id`, dependent: destroy)
- `has_many :incoming_links` (class: `DocumentLink`, FK: `target_document_id`, dependent: destroy)
- `has_many :linked_documents` through `outgoing_links` (source: `target_document`)
- `has_many :linking_documents` through `incoming_links` (source: `source_document`)

#### Scenario: Access linked documents

- **WHEN** Document A links to Documents B and C via `[[B]]` and `[[C]]`
- **THEN** `document_a.linked_documents` returns `[B, C]`

#### Scenario: Access backlinks

- **WHEN** Documents B and C both contain `[[A]]`
- **THEN** `document_a.linking_documents` returns `[B, C]`

### Requirement: Link extraction after save

The system SHALL extract wiki-links from document body content after each save via an `after_save` callback. The `DocumentLinkExtractor` service SHALL:

1. Strip HTML tags from the rich text body to get plain text
2. Parse all `[[...]]` occurrences using regex
3. Resolve each title to a `document_id` by **exact case-insensitive title match**
4. Delete all existing outgoing links for the document
5. Insert new `DocumentLink` records for each resolved reference

#### Scenario: Links extracted on document save

- **WHEN** a document with body containing `[[Meeting Notes]]` is saved
- **AND** a document titled "Meeting Notes" exists
- **THEN** a `DocumentLink` is created from the saved document to "Meeting Notes"

#### Scenario: Unresolvable links ignored

- **WHEN** a document contains `[[Nonexistent Note]]`
- **AND** no document with title "Nonexistent Note" exists
- **THEN** no `DocumentLink` is created for that reference

#### Scenario: Case-insensitive title matching

- **WHEN** a document contains `[[meeting notes]]`
- **AND** a document titled "Meeting Notes" exists
- **THEN** a `DocumentLink` is created to "Meeting Notes"

#### Scenario: Self-references ignored

- **WHEN** a document titled "My Note" contains `[[My Note]]`
- **THEN** no `DocumentLink` is created (source = target)

### Requirement: Document search endpoint

The system SHALL provide `GET /documents/search.json?q=<query>` returning JSON array `[{id, title}]` of documents whose titles contain the query string (case-insensitive). Results SHALL be limited to 10 entries.

#### Scenario: Search returns matching documents

- **WHEN** `GET /documents/search.json?q=meet` is requested
- **AND** documents "Meeting Notes" and "Team Meeting" exist
- **THEN** response is `200 OK` with JSON containing both documents

#### Scenario: Empty query returns empty array

- **WHEN** `GET /documents/search.json?q=` is requested
- **THEN** response is `200 OK` with `[]`

### Requirement: Wiki-link autocomplete in editor

A Stimulus controller `wiki-link-controller` SHALL provide autocomplete when the user types `[[` in the rich text editor:

1. Detect `[[` input pattern in the editor
2. Show a dropdown with live search results from `GET /documents/search.json?q=...`
3. On selection, insert the wiki-link text `[[Selected Title]]` into the editor
4. Close the dropdown on Escape or clicking outside

#### Scenario: Autocomplete triggers on double bracket

- **WHEN** user types `[[` in the editor
- **THEN** a dropdown appears with document title suggestions

#### Scenario: Autocomplete filters on typing

- **WHEN** user types `[[meet`
- **THEN** the dropdown filters to show documents matching "meet"

#### Scenario: Selection inserts wiki-link

- **WHEN** user selects "Meeting Notes" from the autocomplete dropdown
- **THEN** `[[Meeting Notes]]` is inserted into the editor at the cursor position

#### Scenario: Escape closes autocomplete

- **WHEN** the autocomplete dropdown is open
- **AND** user presses Escape
- **THEN** the dropdown closes without inserting anything

### Requirement: Wiki-link rendering

When displaying document content, `[[Title]]` patterns SHALL be rendered as clickable HTML links pointing to the referenced document's show page. Unresolvable `[[Title]]` SHALL be rendered as plain text with a distinct "broken link" style.

#### Scenario: Valid wiki-link rendered as anchor

- **WHEN** document body contains `[[Meeting Notes]]`
- **AND** "Meeting Notes" document exists at `/documents/123`
- **THEN** it renders as `<a href="/documents/123" class="wiki-link">Meeting Notes</a>`

#### Scenario: Broken wiki-link rendered with distinct style

- **WHEN** document body contains `[[Nonexistent]]`
- **AND** no document with that title exists
- **THEN** it renders as `<span class="wiki-link wiki-link--broken">Nonexistent</span>`

### Requirement: Backlinks display on document page

The document show page SHALL display a "Mentioned in" section at the bottom listing all documents that link to the current document (backlinks). Each entry shows the document title and its `updated_at` date. The section SHALL only appear when `linking_documents.any?` is true.

#### Scenario: Backlinks displayed

- **WHEN** viewing Document A
- **AND** Documents B and C contain `[[A]]`
- **THEN** a "Mentioned in" section appears listing B and C with their titles and updated dates

#### Scenario: No backlinks section when no backlinks exist

- **WHEN** viewing Document A
- **AND** no other document references `[[A]]`
- **THEN** the "Mentioned in" section is not rendered
