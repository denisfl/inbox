## 1. Routes

- [ ] 1.1 Update `config/routes.rb` — change web UI `resources :documents` from `only: [:index, :show, :edit, :new]` to `only: [:index, :show, :edit, :new, :destroy]`

## 2. Controller

- [ ] 2.1 Add `destroy` action to `DocumentsController`:
  ```ruby
  def destroy
    @document = Document.find(params[:id])
    @document.destroy!
    redirect_to documents_path, notice: "Note deleted."
  end
  ```
- [ ] 2.2 Verify `set_document` private method is used for `:destroy` too (or inline `find`)

## 3. Views — Index Page

- [ ] 3.1 Add a delete button/link to each document row in `app/views/documents/index.html.erb`:
  ```erb
  <%= link_to "Delete",
    document_path(document),
    data: { turbo_method: :delete, turbo_confirm: "Delete this note? This cannot be undone." },
    class: "..." %>
  ```

## 4. Views — Show/Edit Page

- [ ] 4.1 Add delete button to `app/views/documents/show.html.erb` (if it exists) with the same `turbo_method: :delete` and confirm
- [ ] 4.2 Add delete button to `app/views/documents/edit.html.erb` with confirm

## 5. Flash Messages

- [ ] 5.1 Ensure `app/views/layouts/application.html.erb` renders flash notices/alerts (check if already present; add if not)

## 6. Verification

- [ ] 6.1 Manual test: create a document via web UI → delete it → confirm it disappears from index
- [ ] 6.2 Manual test: send a voice note via Telegram (with attachment) → delete the created document → verify no orphaned blobs in storage
- [ ] 6.3 Manual test: dismiss confirm dialog → document remains
- [ ] 6.4 Check `ActiveStorage::Blob.count` before and after deletion to verify blobs are purged
