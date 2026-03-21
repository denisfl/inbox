## Why

Documents in Inbox are isolated — there's no way to connect related notes. Knowledge management tools like Obsidian prove that bidirectional links (`[[Note Title]]`) turn a flat collection of notes into a connected knowledge graph. Without links, users lose context about how ideas relate to each other, and valuable connections between notes remain invisible.

## What Changes

- New `document_links` join table storing directional links between documents (source → target)
- `Document` model gains `outgoing_links`, `incoming_links`, `linked_documents`, `linking_documents` associations
- `DocumentLinkExtractor` service parses `[[...]]` syntax from rich text content after each save, resolving titles to document IDs and syncing the `document_links` table
- New Stimulus controller `wiki-link-controller` provides autocomplete dropdown when typing `[[` in the editor, with live search via `GET /documents/search.json?q=...`
- Documents render `[[Title]]` as clickable links to the referenced document
- Document show page displays "Mentioned in" section listing incoming backlinks (title + updated_at)

## Capabilities

### New Capabilities

- `wiki-links`: Bidirectional document linking via `[[Title]]` syntax — storage, extraction, autocomplete, rendering, and backlink display

### Modified Capabilities

<!-- No existing spec-level behavior changes -->

## Impact

- **Database**: New `document_links` table with foreign keys to `documents`
- **Models**: `Document` gets new associations and `after_save` callback; new `DocumentLink` model
- **Controllers**: `DocumentsController` gains `search` JSON endpoint
- **Routes**: New `GET /documents/search` route
- **JavaScript**: New `wiki-link-controller` Stimulus controller integrated with the rich text editor (ActionText/Trix)
- **Views**: Document show page gets "Mentioned in" backlinks section; rich text rendering converts `[[...]]` to `<a>` tags
- **Dependencies**: None — uses existing ActionText, Stimulus, SQLite
