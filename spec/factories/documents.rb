FactoryBot.define do
  factory :document do
    title { Faker::Lorem.sentence(word_count: 3) }
    slug { title.parameterize }
    source { %w[web telegram email].sample }
    body { Faker::Lorem.paragraph }
  end
end
