## Context

Inbox is a personal knowledge management app (Rails 8.1, SQLite3, ActionText/Trix, Stimulus.js). Documents are currently isolated — there's no mechanism to express relationships between notes. The `Document` model has `title`, `body` (ActionText rich text), tags, and FTS search. The editor uses Trix via ActionText's `rich_text_area`.

## Goals / Non-Goals

**Goals:**
- Store bidirectional document links in the database
- Extract `[[Title]]` references from rich text on save
- Provide autocomplete in the Trix editor when typing `[[`
- Render wiki-links as clickable HTML links
- Show backlinks ("Mentioned in") on each document page

**Non-Goals:**
- Block-level linking (linking to specific sections within a document)
- Automatic link suggestions based on content similarity
- Graph visualization of document connections
- Markdown `[[wikilink]]` syntax — this is rich text only

## Decisions

### 1. Storage: Join table with directional links
**Decision**: Use a `document_links` table with `source_document_id` → `target_document_id`.
**Rationale**: Simple, queryable, supports both directions through associations. No need for a graph DB at our scale.
**Alternative**: Store links as JSON array on the document — rejected because querying backlinks would require scanning all documents.

### 2. Link extraction: after_save callback with service object
**Decision**: `DocumentLinkExtractor` service called from `Document#after_save`. Strips HTML from `body.to_plain_text`, extracts `[[...]]` with regex, resolves by case-insensitive title match, then replaces all outgoing links.
**Rationale**: Simple, synchronous, predictable. Document count is small (< 10k) so performance is fine.
**Alternative**: Background job for extraction — rejected as unnecessary complexity for our scale.

### 3. Title resolution: Exact case-insensitive match
**Decision**: `Document.where("LOWER(title) = LOWER(?)", extracted_title).first`
**Rationale**: Predictable, no ambiguity. If no match, the link is simply unresolved (rendered as broken link).
**Alternative**: Fuzzy matching — rejected because it could create incorrect links silently.

### 4. Autocomplete: Stimulus controller + Trix API
**Decision**: New `wiki-link-controller` monitors Trix editor input. On detecting `[[`, shows a dropdown positioned at the cursor. Uses `GET /documents/search.json?q=...` for live search. On selection, inserts `[[Title]]` as text via Trix's `editor.insertString()`.
**Rationale**: Trix's document model treats `[[Title]]` as plain text, which is what we need for extraction. No custom Trix extensions required.
**Alternative**: Custom Trix attachment — rejected as overengineered for text-based links.

### 5. Rendering: Helper method wrapping ActionText output
**Decision**: Create `WikiLinkRenderer` helper that post-processes rendered HTML, replacing `[[Title]]` patterns with `<a>` tags. Called in the document show view after `body` rendering.
**Rationale**: Keeps ActionText/Trix unmodified. The `[[...]]` text survives Trix round-trips naturally since it's just text.
**Alternative**: Custom ActionText attachment type — rejected because of complexity and Trix extension requirements.

### 6. Search endpoint: Reuse DocumentsController
**Decision**: Add `search` action to `DocumentsController` responding to JSON format.
**Rationale**: Keeps routing simple. The search is a lightweight title LIKE query, not a full FTS search.

## Risks / Trade-offs

- **[Title renames break links]** → When a document title changes, existing `[[OldTitle]]` in other documents become broken. Mitigation: Accept this limitation initially; future enhancement could auto-update references.
- **[Performance of full-table link extraction]** → Each save deletes and re-inserts all outgoing links. At < 10k documents this is negligible. Mitigation: If scale grows, switch to diff-based extraction.
- **[Trix cursor position for dropdown]** → Trix doesn't expose pixel-level cursor position natively. Mitigation: Use `window.getSelection()` + `Range.getBoundingClientRect()` to position the dropdown.

## Migration Plan

1. Create `document_links` migration
2. Add model, associations, service
3. Add search endpoint + route
4. Add Stimulus controller
5. Add rendering helper + backlinks section
6. Run `DocumentLinkExtractor` on all existing documents to build initial link graph

**Rollback**: Drop `document_links` table. No data loss — links are derived from content.
