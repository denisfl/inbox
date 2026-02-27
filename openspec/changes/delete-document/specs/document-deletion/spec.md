## ADDED Requirements

### Requirement: Document can be deleted via web UI
A signed-in user SHALL be able to delete any document through the web UI. Deletion is permanent and removes all associated data.

#### Scenario: Delete from index page
- **GIVEN** the user is on the documents index page
- **WHEN** the user clicks the "Delete" button for a document and confirms the dialog
- **THEN** the document and all its blocks, tags (join records), and ActiveStorage blobs SHALL be permanently destroyed
- **AND** the user SHALL be redirected to the documents index with a success flash message
- **AND** the deleted document SHALL NOT appear in the list

#### Scenario: Delete from show/edit page
- **GIVEN** the user is viewing or editing a document
- **WHEN** the user clicks the "Delete" button and confirms
- **THEN** the document SHALL be destroyed and the user redirected to the documents index

#### Scenario: Deletion requires confirmation
- **GIVEN** the user is on any page with a delete button
- **WHEN** the user clicks "Delete" but dismisses the confirmation dialog
- **THEN** the document SHALL NOT be deleted and the page SHALL remain unchanged

### Requirement: Associated records are purged on deletion
When a document is destroyed, all associated data SHALL be removed:

#### Scenario: Blocks destroyed with document
- **WHEN** a document is deleted
- **THEN** all `Block` records belonging to that document SHALL be destroyed (`dependent: :destroy`)

#### Scenario: ActiveStorage blobs purged
- **WHEN** a `Block` with an attached file or image is destroyed
- **THEN** the associated ActiveStorage blob and attachment records SHALL be purged (no orphaned blobs)

#### Scenario: Tag join records destroyed
- **WHEN** a document is deleted
- **THEN** all `DocumentTag` join records for that document SHALL be destroyed
- **AND** the `Tag` records themselves SHALL NOT be deleted (shared across documents)

### Requirement: Route and action exist
The Rails router and controller SHALL handle DELETE requests for documents.

#### Scenario: DELETE /documents/:id is routed
- **GIVEN** a valid document ID
- **WHEN** a DELETE request is sent to `/documents/:id`
- **THEN** `DocumentsController#destroy` SHALL be invoked

#### Scenario: Non-existent document returns 404
- **WHEN** a DELETE request is sent to `/documents/:id` for a non-existent ID
- **THEN** the server SHALL respond with HTTP 404
