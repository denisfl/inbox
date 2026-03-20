# frozen_string_literal: true

class MigrateMarkdownToActionText < ActiveRecord::Migration[8.1]
  def up
    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(hard_wrap: true, link_attributes: { target: "_blank" }),
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      no_intra_emphasis: true
    )

    # Migrate tasks.description
    execute_sql = "SELECT id, description FROM tasks WHERE description IS NOT NULL AND description != ''"
    ActiveRecord::Base.connection.select_all(execute_sql).each do |row|
      html = markdown.render(row["description"])
      rich_text = ActionText::RichText.find_or_initialize_by(
        record_type: "Task",
        record_id: row["id"],
        name: "description"
      )
      rich_text.update!(body: html)
    end

    # Migrate calendar_events.description
    execute_sql = "SELECT id, description FROM calendar_events WHERE description IS NOT NULL AND description != ''"
    ActiveRecord::Base.connection.select_all(execute_sql).each do |row|
      html = markdown.render(row["description"])
      rich_text = ActionText::RichText.find_or_initialize_by(
        record_type: "CalendarEvent",
        record_id: row["id"],
        name: "description"
      )
      rich_text.update!(body: html)
    end

    # Migrate document blocks → single rich text body per document
    documents_with_text = ActiveRecord::Base.connection.select_all(<<~SQL)
      SELECT DISTINCT document_id FROM blocks WHERE block_type = 'text'
    SQL

    documents_with_text.each do |row|
      doc_id = row["document_id"]
      blocks = ActiveRecord::Base.connection.select_all(
        "SELECT content FROM blocks WHERE document_id = #{doc_id.to_i} AND block_type = 'text' ORDER BY position ASC"
      )

      combined_text = blocks.map do |block|
        content_json = block["content"]
        next nil if content_json.blank?
        begin
          data = JSON.parse(content_json)
          data["text"]
        rescue JSON::ParserError
          nil
        end
      end.compact.join("\n\n")

      next if combined_text.blank?

      html = markdown.render(combined_text)
      rich_text = ActionText::RichText.find_or_initialize_by(
        record_type: "Document",
        record_id: doc_id,
        name: "body"
      )
      rich_text.update!(body: html)
    end
  end

  def down
    ActionText::RichText.where(record_type: "Task", name: "description").delete_all
    ActionText::RichText.where(record_type: "CalendarEvent", name: "description").delete_all
    ActionText::RichText.where(record_type: "Document", name: "body").delete_all
  end
end
