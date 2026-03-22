class CreateStorageMigrations < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_migrations do |t|
      t.string :from_provider, null: false
      t.string :to_provider, null: false
      t.string :status, null: false, default: "pending"  # pending, running, completed, failed, cancelled
      t.integer :total_items, default: 0
      t.integer :completed_items, default: 0
      t.integer :failed_items, default: 0
      t.text :error_log
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :storage_migrations, :status
  end
end
