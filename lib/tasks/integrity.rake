namespace :db do
  desc "Check referential integrity across all tables"
  task integrity_check: :environment do
    orphans = []

    # document_links: source_document_id and target_document_id → documents
    orphans += find_orphans("document_links", "source_document_id", "documents")
    orphans += find_orphans("document_links", "target_document_id", "documents")

    # document_tags: document_id → documents, tag_id → tags
    orphans += find_orphans("document_tags", "document_id", "documents")
    orphans += find_orphans("document_tags", "tag_id", "tags")

    # task_tags: task_id → tasks, tag_id → tags
    orphans += find_orphans("task_tags", "task_id", "tasks")
    orphans += find_orphans("task_tags", "tag_id", "tags")

    # calendar_event_tags: calendar_event_id → calendar_events, tag_id → tags
    orphans += find_orphans("calendar_event_tags", "calendar_event_id", "calendar_events")
    orphans += find_orphans("calendar_event_tags", "tag_id", "tags")

    # blocks: document_id → documents
    orphans += find_orphans("blocks", "document_id", "documents")

    # tasks: document_id → documents (optional FK, but check for orphans)
    orphans += find_orphans("tasks", "document_id", "documents")

    # ActionText rich_text records: record_id → parent table
    orphans += find_action_text_orphans

    if orphans.empty?
      puts "Integrity check passed"
      exit 0
    else
      puts "Integrity check FAILED — #{orphans.size} orphan(s) found:\n\n"
      orphans.each do |o|
        puts "  #{o[:table]} id=#{o[:record_id]} → #{o[:fk_column]} references missing #{o[:references]} id=#{o[:missing_id]}"
      end
      exit 1
    end
  end
end

def find_orphans(table, fk_column, referenced_table)
  sql = <<-SQL
    SELECT #{table}.id, #{table}.#{fk_column}
    FROM #{table}
    LEFT JOIN #{referenced_table} ON #{referenced_table}.id = #{table}.#{fk_column}
    WHERE #{table}.#{fk_column} IS NOT NULL
      AND #{referenced_table}.id IS NULL
  SQL

  ActiveRecord::Base.connection.select_all(sql).map do |row|
    {
      table: table,
      record_id: row["id"],
      fk_column: fk_column,
      references: referenced_table,
      missing_id: row[fk_column]
    }
  end
end

def find_action_text_orphans
  orphans = []
  # Check action_text_rich_texts for orphan record references
  return orphans unless ActiveRecord::Base.connection.table_exists?("action_text_rich_texts")

  record_types = ActiveRecord::Base.connection.select_values(
    "SELECT DISTINCT record_type FROM action_text_rich_texts"
  )

  record_types.each do |record_type|
    table_name = record_type.tableize
    next unless ActiveRecord::Base.connection.table_exists?(table_name)

    quoted_type = ActiveRecord::Base.connection.quote(record_type)
    quoted_table = ActiveRecord::Base.connection.quote_table_name(table_name)

    sql = <<-SQL
      SELECT art.id, art.record_id
      FROM action_text_rich_texts art
      LEFT JOIN #{quoted_table} ON #{quoted_table}.id = art.record_id
      WHERE art.record_type = #{quoted_type}
        AND #{quoted_table}.id IS NULL
    SQL

    ActiveRecord::Base.connection.select_all(sql).each do |row|
      orphans << {
        table: "action_text_rich_texts",
        record_id: row["id"],
        fk_column: "record_id",
        references: table_name,
        missing_id: row["record_id"]
      }
    end
  end

  orphans
end
