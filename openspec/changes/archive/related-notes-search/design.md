## Context

After a voice note is transcribed, the user has no way to discover existing documents with similar content. Notes about the same topic accumulate without connection. Surfacing related documents after transcription would help the user build context and avoid duplicates.

The system already uses SQLite FTS5 for search (`documents_fts` table). Ollama is available for semantic analysis. The simplest effective approach is a lightweight text similarity check using existing FTS5 infrastructure — no new dependencies needed for the baseline implementation.

## Goals / Non-Goals

**Goals:**

- After a document is created or its text content changes (via transcription), find the top-N most similar existing documents
- Store relation results transiently (in memory for now; optionally persist)
- Surface related documents in the document show/edit view
- Run the search asynchronously (background job) to not block the transcription response

**Non-Goals:**

- Real-time semantic embeddings (Ollama embeddings are a future enhancement)
- Bi-directional relation graph / knowledge graph
- Persisting similarity scores in a separate table (v1 can query on-the-fly or cache on document)
- Cross-language similarity (Russian ↔ English)

## Decisions

### Decision: SQLite FTS5 similarity search (v1)

**Chosen:** Reuse the existing `documents_fts` MATCH query. After transcription, extract key terms from the new document's content and run an FTS5 MATCH query against all other documents. Return top-5 results by BM25 rank.

**Rationale:**

- Zero new dependencies
- FTS5 already indexed — fast
- Good enough for keyword-based Russian text similarity

**Future:** Can swap in Ollama embeddings (`/api/embeddings`) for semantic similarity.

### Decision: Store related document IDs in Document metadata column

Add a `related_document_ids` JSON column to `documents` table (or use an existing metadata approach). Stored after the async job completes. UI reads from this column.

**Migration needed:** `add_column :documents, :related_document_ids, :text` (store as JSON array).

**Alternative:** Query on every page load — rejected (too slow for FTS5 with many documents).

### Decision: `FindRelatedNotesJob` enqueued from `TranscribeAudioJob`

After successful transcription, `TranscribeAudioJob` enqueues `FindRelatedNotesJob.perform_later(document.id)`. The related-notes job runs independently — transcription does not depend on it.

### Decision: UI — "Related Notes" section in document show view

A simple list of links to related documents at the bottom of `documents/show.html.erb`. Only shown if `document.related_document_ids.present?`.

## Risks / Trade-offs

- **Risk:** FTS5 keywords are too broad → many false positives → **Mitigation:** Use the top 3–5 content words (filter stop words); take only top-3 results with a minimum rank threshold.
- **Risk:** `related_document_ids` becomes stale (related doc deleted) → **Mitigation:** Filter out deleted IDs when rendering the UI.
- **Risk:** DB migration required → **Mitigation:** Simple `add_column` migration, no data changes needed.
