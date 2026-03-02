FactoryBot.define do
  factory :document do
    title { Faker::Lorem.sentence(word_count: 3) }
    slug { title.parameterize }
    source { %w[web telegram email].sample }
    # Document doesn't have body field - content is in blocks

    # Optional: create with initial text block
    trait :with_initial_block do
      after(:create) do |document|
        create(:block, :text, document: document, position: 0)
      end
    end
  end
end
