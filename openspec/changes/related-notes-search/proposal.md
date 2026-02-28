## Why

After a voice note is transcribed, the user has no way to discover existing documents with related content. Finding connections between notes manually is tedious — automatic similarity search would surface relevant context.

## What Changes

- After a document is saved/transcribed, run a background job to find semantically or lexically similar documents
- Show related documents as a "Related Notes" section in the document show/edit view
- Store relations in a join table or metadata field

## Capabilities

### New Capabilities

- `related-notes-discovery`: After a document is created or updated, a background job computes similarity against existing documents. Results are stored and displayed in the UI.

### New Components

- `FindRelatedNotesJob`: Runs after transcription completes; uses keyword overlap (TF-IDF or simple token matching) or Ollama embeddings for semantic similarity
- `DocumentRelation` model (or metadata field): Stores pairs of related document IDs with a similarity score
- UI component: "Related Notes" panel in document show view

## Impact

- **Code**: New `FindRelatedNotesJob`; `TranscribeAudioJob` enqueues it after transcription
- **Model**: New `document_relations` table (`document_id`, `related_document_id`, `score`) or JSON metadata on `Document`
- **View**: `documents/show` — add related notes sidebar/panel
- **Performance**: job runs async; only top-N results stored
- **Dependencies**: Ollama (already present) if using embeddings; otherwise pure Ruby/SQL approach
