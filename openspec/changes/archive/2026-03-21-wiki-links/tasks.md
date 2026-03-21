## 1. Database & Model

- [x] 1.1 Create migration for `document_links` table (source_document_id, target_document_id, timestamps, unique index)
- [x] 1.2 Create `DocumentLink` model with belongs_to associations and validations
- [x] 1.3 Add associations to `Document` model (outgoing_links, incoming_links, linked_documents, linking_documents)
- [x] 1.4 Write model specs: DocumentLink validations, uniqueness constraint, cascading destroy
- [x] 1.5 Write model specs: Document associations (linked_documents, linking_documents)

## 2. Link Extraction Service

- [x] 2.1 Create `DocumentLinkExtractor` service — accepts a document, strips HTML from body, extracts `[[...]]` patterns via regex
- [x] 2.2 Implement title resolution: case-insensitive exact match, skip self-references, skip unresolvable titles
- [x] 2.3 Implement link sync: delete old outgoing links, create new ones
- [x] 2.4 Wire `after_save` callback on Document to call `DocumentLinkExtractor`
- [x] 2.5 Write service specs: extraction of `[[Title]]` from plain text, multiple links, nested brackets edge cases
- [x] 2.6 Write service specs: case-insensitive matching, self-reference skipping, unresolvable links
- [x] 2.7 Write service specs: link sync — old links removed, new links created, idempotent on re-save

## 3. Search Endpoint

- [x] 3.1 Add `search` action to `DocumentsController` — responds to JSON, queries documents by title LIKE, limit 10
- [x] 3.2 Add route `GET /documents/search` in `config/routes.rb`
- [x] 3.3 Write request specs: search returns matching documents, empty query returns empty array, results capped at 10

## 4. Wiki-Link Rendering

- [x] 4.1 Create `WikiLinkRenderer` helper — post-processes HTML body, replaces `[[Title]]` with `<a>` for resolved links and `<span class="wiki-link--broken">` for unresolved
- [x] 4.2 Add CSS styles for `.wiki-link` and `.wiki-link--broken`
- [x] 4.3 Integrate renderer in document show view
- [x] 4.4 Write helper specs: resolved links generate correct `<a>` tags, broken links render with distinct class

## 5. Backlinks Display

- [x] 5.1 Add "Mentioned in" section to document show view — list linking_documents with title and updated_at
- [x] 5.2 Conditionally render section only when linking_documents exist
- [x] 5.3 Add CSS styles for backlinks section
- [x] 5.4 Write view/request specs: backlinks displayed when present, section hidden when no backlinks

## 6. Autocomplete Stimulus Controller

- [x] 6.1 Create `wiki-link-controller` Stimulus controller — detect `[[` input in Lexxy editor
- [x] 6.2 Implement dropdown rendering with live search from `/documents/search.json`
- [x] 6.3 Implement keyboard navigation (ArrowUp/Down, Enter to select, Escape to close)
- [x] 6.4 Insert `[[Selected Title]]` via text node manipulation on selection
- [x] 6.5 Position dropdown using `window.getSelection()` + `Range.getBoundingClientRect()`
- [x] 6.6 Register controller in `app/javascript/controllers/index.js`
- [x] 6.7 Wire controller to Lexxy editor in document edit view

## 7. Initial Link Graph & Verification

- [x] 7.1 Create rake task `links:extract_all` to run `DocumentLinkExtractor` on all existing documents
- [x] 7.2 Run full test suite — confirm 0 failures, no regressions
