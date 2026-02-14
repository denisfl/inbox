FactoryBot.define do
  factory :document_tag do
    association :document
    association :tag
  end
end
