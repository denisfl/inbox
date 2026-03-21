class AddStatusToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :status, :string, default: "inbox", null: false
    add_index :documents, :status
  end
end
