class CreateDocumentLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :document_links do |t|
      t.integer :source_document_id, null: false
      t.integer :target_document_id, null: false

      t.timestamps
    end

    add_index :document_links, [ :source_document_id, :target_document_id ], unique: true
    add_index :document_links, :target_document_id
  end
end
