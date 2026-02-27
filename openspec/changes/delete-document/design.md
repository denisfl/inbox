## Context

The application is a personal notes app. Documents accumulate over time via Telegram (voice notes, photos, text) and the web UI. Currently there is no way to delete a document — the `DocumentsController` only exposes `index`, `show`, `edit`, and `new`. Old or incorrect notes permanently clutter the list.

The system is single-user. There is no soft-delete requirement — a hard destroy with ActiveStorage purge is sufficient.

## Goals / Non-Goals

**Goals:**
- Allow the user to delete any document from the documents index or show/edit view
- Destroy all associated records (blocks, tags via join table, ActiveStorage blobs)
- Confirm deletion before executing (browser `confirm` dialog or Turbo confirm)
- No pagination/routing side effects after deletion

**Non-Goals:**
- Soft delete / trash bin / undo
- Bulk delete from index (can be added later)
- API endpoint for deletion (only web UI for now)

## Decisions

### Decision: Hard delete via Rails `destroy`

`Document` already has `has_many :blocks, dependent: :destroy`. Blocks have ActiveStorage attachments (`image`, `file`). Rails `dependent: :destroy` on blocks triggers `before_destroy` callbacks in ActiveStorage, which purges blobs. `DocumentTag` also has `dependent: :destroy`. So calling `document.destroy!` is sufficient for complete cleanup.

### Decision: Confirmation via Turbo confirm

Use `data: { turbo_method: :delete, turbo_confirm: "Delete this note?" }` on the delete link/button. This uses Stimulus + Turbo (already in the stack via `importmap`) — no extra JS needed.

### Decision: Redirect to `documents_path` after delete

After destroy, redirect to the documents index with a flash notice. This is the standard Rails pattern and avoids hitting a now-missing resource URL.

### Decision: Route

Add `destroy` action to the existing `resources :documents` web UI route block (currently only `index`, `show`, `edit`, `new`). Change to `only: [:index, :show, :edit, :new, :destroy]`.

## Risks / Trade-offs

- **Risk:** Accidental deletion is permanent → **Mitigation:** Browser confirm dialog before DELETE request.
- **Risk:** ActiveStorage blobs may not be purged if `dependent: :destroy` is misconfigured → **Mitigation:** Verify `has_one_attached :file` and `has_one_attached :image` on `Block` — Rails ActiveStorage purges blobs automatically on record destroy.
- **Risk:** `document_tags` join records already have `dependent: :destroy` on `Document` → **Verified:** `has_many :document_tags, dependent: :destroy` in `Document` model.

## Migration Plan

1. Add `destroy` to `DocumentsController` — find and destroy; redirect with flash
2. Update routes — add `:destroy` to web UI `resources :documents`
3. Add delete button/link to documents index (per-row action)
4. Add delete button to document show/edit view
5. Deploy — no DB migration needed
