class AddForeignKeysToDocumentLinks < ActiveRecord::Migration[8.0]
  def up
    # Clean orphan document_links where source or target document doesn't exist
    execute <<-SQL
      DELETE FROM document_links
      WHERE source_document_id NOT IN (SELECT id FROM documents)
         OR target_document_id NOT IN (SELECT id FROM documents)
    SQL

    # Clean orphan document_tags
    execute <<-SQL
      DELETE FROM document_tags
      WHERE document_id NOT IN (SELECT id FROM documents)
         OR tag_id NOT IN (SELECT id FROM tags)
    SQL

    # Clean orphan task_tags
    execute <<-SQL
      DELETE FROM task_tags
      WHERE task_id NOT IN (SELECT id FROM tasks)
         OR tag_id NOT IN (SELECT id FROM tags)
    SQL

    # Clean orphan calendar_event_tags
    execute <<-SQL
      DELETE FROM calendar_event_tags
      WHERE calendar_event_id NOT IN (SELECT id FROM calendar_events)
         OR tag_id NOT IN (SELECT id FROM tags)
    SQL

    # Clean orphan blocks
    execute <<-SQL
      DELETE FROM blocks
      WHERE document_id NOT IN (SELECT id FROM documents)
    SQL

    # Add foreign keys for document_links (only table missing them)
    add_foreign_key :document_links, :documents, column: :source_document_id
    add_foreign_key :document_links, :documents, column: :target_document_id
  end

  def down
    remove_foreign_key :document_links, column: :source_document_id
    remove_foreign_key :document_links, column: :target_document_id
  end
end
