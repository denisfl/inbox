FactoryBot.define do
  factory :block do
    association :document
    block_type { Block::BLOCK_TYPES.sample }
    position { 0 }
    content { { text: Faker::Lorem.paragraph }.to_json }

    trait :text do
      block_type { 'text' }
      content { { text: Faker::Lorem.paragraph }.to_json }
    end

    trait :heading do
      block_type { 'heading' }
      content { { text: Faker::Lorem.sentence, level: rand(1..3) }.to_json }
    end

    trait :todo do
      block_type { 'todo' }
      content { { text: Faker::Lorem.sentence, checked: [ true, false ].sample }.to_json }
    end

    trait :code do
      block_type { 'code' }
      content { { code: 'puts "Hello World"', language: 'ruby' }.to_json }
    end

    trait :image do
      block_type { 'image' }
      content { { url: Faker::Internet.url, alt: Faker::Lorem.sentence }.to_json }
    end
  end
end
