FactoryBot.define do
  factory :document_link do
    association :source_document, factory: :document
    association :target_document, factory: :document
  end
end
