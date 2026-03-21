class DocumentLink < ApplicationRecord
  belongs_to :source_document, class_name: "Document"
  belongs_to :target_document, class_name: "Document"

  validates :source_document_id, uniqueness: { scope: :target_document_id }
end
