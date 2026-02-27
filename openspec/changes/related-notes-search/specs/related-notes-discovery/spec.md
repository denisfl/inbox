## ADDED Requirements

### Requirement: Related notes are found after transcription
After a voice note is successfully transcribed, the system SHALL asynchronously search for similar existing documents and store the results on the document.

#### Scenario: Related documents found after transcription
- **GIVEN** a voice note is transcribed and the document has text content
- **WHEN** `FindRelatedNotesJob` runs
- **THEN** the system SHALL query for up to 5 most similar existing documents (excluding the current one)
- **AND** the matching document IDs SHALL be stored on `document.related_document_ids`

#### Scenario: No related documents found
- **GIVEN** the transcription text contains no significant keywords matching other documents
- **WHEN** `FindRelatedNotesJob` runs
- **THEN** `document.related_document_ids` SHALL be set to an empty array (not nil)
- **AND** the document SHALL be saved successfully

#### Scenario: Job runs asynchronously
- **WHEN** transcription completes
- **THEN** `FindRelatedNotesJob` SHALL be enqueued AFTER the transcription text block is saved
- **AND** the Telegram reply to the user SHALL NOT wait for the related-notes job

### Requirement: Related notes displayed in document show view
If related documents exist, they SHALL be shown in the document show view.

#### Scenario: Related notes section shown
- **GIVEN** a document has `related_document_ids` populated with valid document IDs
- **WHEN** the user views the document at `/documents/:id`
- **THEN** a "Related Notes" section SHALL appear with links to each related document (title + link)

#### Scenario: Related notes section hidden when empty
- **GIVEN** a document has no related documents (empty or nil `related_document_ids`)
- **WHEN** the user views the document
- **THEN** the "Related Notes" section SHALL NOT be rendered

#### Scenario: Deleted related document handled gracefully
- **GIVEN** a related document ID stored on a document has since been deleted
- **WHEN** the show view renders
- **THEN** the deleted document SHALL be silently excluded from the list (no error raised)

### Requirement: Similarity search uses FTS5
The similarity search SHALL use the existing SQLite FTS5 index (`documents_fts`).

#### Scenario: FTS5 query runs against content
- **WHEN** `FindRelatedNotesJob` searches for related documents
- **THEN** it SHALL use significant words from the document's text content as the FTS5 query
- **AND** results SHALL be ordered by BM25 relevance score
- **AND** the current document SHALL be excluded from results
