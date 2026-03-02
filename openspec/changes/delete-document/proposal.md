## Why

Documents accumulate over time and there's no way to remove them. Users need the ability to delete notes they no longer need — both individually and in bulk.

## What Changes

- Add delete button to document edit page and documents list
- Add bulk selection and bulk delete on documents index
- Soft-delete or hard-delete with confirmation dialog (Turbo confirm)
- Telegram: optionally notify user when a document is deleted

## Capabilities

### New Capabilities

- `document-deletion`: Users can delete individual documents and their associated blocks, tags, and file attachments. Includes confirmation dialog to prevent accidental deletion. Bulk delete from index page.

### Modified Capabilities

- none

## Impact

- **Code**: `DocumentsController` — add `destroy` action; routes — add `DELETE /documents/:id`; views — add delete buttons in edit and index; `Document` model — `dependent: :destroy` on associations
- **ActiveStorage**: file blobs must be purged on delete
- **No new dependencies**
- **Reversibility**: hard delete (no recycle bin); irreversible
