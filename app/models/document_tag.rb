class DocumentTag < ApplicationRecord
  belongs_to :document
  belongs_to :tag

  # Validations
  validates :document_id, uniqueness: { scope: :tag_id }
end
