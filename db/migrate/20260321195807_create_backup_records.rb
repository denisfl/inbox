class CreateBackupRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :backup_records do |t|
      t.string :status, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :size_bytes
      t.string :storage_path
      t.string :storage_type, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :backup_records, :status
    add_index :backup_records, :started_at
  end
end
