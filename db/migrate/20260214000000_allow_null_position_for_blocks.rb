class AllowNullPositionForBlocks < ActiveRecord::Migration[7.0]
  def up
    # Create documents table if it doesn't exist
    unless table_exists?(:documents)
      create_table :documents do |t|
        t.string :title
        t.text :content
        t.timestamps
      end
    end

    # Create or recreate blocks table with NULL position allowed
    if table_exists?(:blocks)
      # SQLite doesn't fully support ALTER COLUMN, so we need to recreate the table
      # https://www.sqlite.org/lang_altertable.html

      # Temporarily disable foreign keys
      execute "PRAGMA foreign_keys = OFF"

      # Create new table with correct schema
      create_table :blocks_new do |t|
        t.references :document, null: false
        t.string :block_type, null: false
        t.integer :position # NO default, NULL allowed
        t.text :content
        t.timestamps
      end

      # Copy data
      execute "INSERT INTO blocks_new (id, document_id, block_type, position, content, created_at, updated_at) SELECT id, document_id, block_type, position, content, created_at, updated_at FROM blocks"

      # Drop old table and rename new one
      drop_table :blocks
      rename_table :blocks_new, :blocks

      # Recreate index and foreign key
      add_index :blocks, [:document_id, :position]
      add_foreign_key :blocks, :documents

      # Re-enable foreign keys
      execute "PRAGMA foreign_keys = ON"
    else
      # Table doesn't exist yet - create it from scratch
      create_table :blocks do |t|
        t.references :document, null: false, foreign_key: true
        t.string :block_type, null: false
        t.integer :position # NO default, NULL allowed
        t.text :content
        t.timestamps
      end

      add_index :blocks, [:document_id, :position]
    end
  end

  def down
    if table_exists?(:blocks)
      execute "PRAGMA foreign_keys = OFF"

      create_table :blocks_new do |t|
        t.references :document, null: false
        t.string :block_type, null: false
        t.integer :position, null: false, default: 0
        t.text :content
        t.timestamps
      end

      execute "INSERT INTO blocks_new (id, document_id, block_type, position, content, created_at, updated_at) SELECT id, document_id, block_type, position, content, created_at, updated_at FROM blocks"

      drop_table :blocks
      rename_table :blocks_new, :blocks

      add_index :blocks, [:document_id, :position]
      add_foreign_key :blocks, :documents

      execute "PRAGMA foreign_keys = ON"
    end
  end
end
