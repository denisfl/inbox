class AddDocumentTypeToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :document_type, :string, default: "note", null: false
    add_index :documents, :document_type
  end
end
