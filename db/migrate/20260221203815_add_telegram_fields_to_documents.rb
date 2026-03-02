class AddTelegramFieldsToDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :documents, :source, :string
    add_column :documents, :slug, :string
    add_column :documents, :telegram_chat_id, :integer, limit: 8
    add_column :documents, :telegram_message_id, :integer, limit: 8

    add_index :documents, :slug, unique: true
    add_index :documents, :source
    add_index :documents, [ :telegram_chat_id, :telegram_message_id ]
  end
end
