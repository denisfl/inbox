## 1. Database Migration

- [ ] 1.1 Generate migration: `rails generate migration AddRelatedDocumentIdsToDocuments related_document_ids:text`
- [ ] 1.2 Run migration on development: `rails db:migrate`
- [ ] 1.3 Run migration on RPi production after deploy: `docker compose ... run --rm web rails db:migrate`

## 2. Document Model

- [ ] 2.1 Add accessor helper to `app/models/document.rb`:

  ```ruby
  def related_document_ids
    JSON.parse(self[:related_document_ids] || '[]')
  rescue JSON::ParserError
    []
  end

  def related_document_ids=(ids)
    self[:related_document_ids] = ids.to_json
  end

  def related_documents
    ids = related_document_ids
    return Document.none if ids.empty?
    Document.where(id: ids)
  end
  ```

## 3. FindRelatedNotesJob

- [ ] 3.1 Create `app/jobs/find_related_notes_job.rb`:

  ```ruby
  class FindRelatedNotesJob < ApplicationJob
    queue_as :default

    def perform(document_id)
      document = Document.find_by(id: document_id)
      return unless document

      # Extract text content from blocks
      text_content = document.blocks
        .where(block_type: 'text')
        .map { |b| JSON.parse(b.content.to_s)['text'].to_s }
        .join(' ')
        .strip

      return if text_content.blank?

      # Build FTS5 query from significant words (3+ chars, top 5)
      words = text_content.downcase.scan(/[а-яёa-z]{3,}/i).uniq.first(5)
      return if words.empty?

      fts_query = words.join(' OR ')

      sql = <<-SQL
        SELECT d.id, bm25(documents_fts) as rank
        FROM documents d
        INNER JOIN documents_fts fts ON fts.document_id = d.id
        WHERE documents_fts MATCH ?
          AND d.id != ?
        ORDER BY rank
        LIMIT 5
      SQL

      results = Document.connection.select_all(
        Document.sanitize_sql([sql, fts_query, document.id])
      )

      related_ids = results.map { |r| r['id'] }
      document.update_column(:related_document_ids, related_ids.to_json)

      Rails.logger.info("Related notes for document #{document_id}: #{related_ids}")
    rescue StandardError => e
      Rails.logger.error("FindRelatedNotesJob failed for #{document_id}: #{e.message}")
    end
  end
  ```

## 4. TranscribeAudioJob — Enqueue FindRelatedNotesJob

- [ ] 4.1 After transcription block is saved and Telegram notification sent, enqueue related notes job:
  ```ruby
  FindRelatedNotesJob.perform_later(document.id)
  ```

## 5. Document Show View

- [ ] 5.1 In `app/views/documents/show.html.erb`, add related notes section at the bottom:
  ```erb
  <% related = @document.related_documents %>
  <% if related.any? %>
    <section class="related-notes">
      <h3>Related Notes</h3>
      <ul>
        <% related.each do |doc| %>
          <li><%= link_to doc.title, document_path(doc) %></li>
        <% end %>
      </ul>
    </section>
  <% end %>
  ```

## 6. Verification

- [ ] 6.1 Send two related voice notes (e.g., both mentioning "встреча") → check that second document has `related_document_ids` pointing to the first
- [ ] 6.2 Open the document show view → verify "Related Notes" section appears with correct link
- [ ] 6.3 Delete a related document → verify the show view doesn't error (graceful exclusion via `Document.where(id: ids)`)
- [ ] 6.4 Check Rails console: `Document.last.related_documents`
