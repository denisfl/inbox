class CreateStorageSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :storage_settings do |t|
      t.string :provider, null: false, default: "local"
      t.text :config_encrypted
      t.boolean :active, null: false, default: true
      t.string :status, default: "unchecked"
      t.datetime :last_checked_at

      t.timestamps
    end
  end
end
