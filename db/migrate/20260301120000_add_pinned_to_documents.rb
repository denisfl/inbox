# frozen_string_literal: true

class AddPinnedToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :pinned, :boolean, null: false, default: false
    add_index :documents, :pinned
  end
end
