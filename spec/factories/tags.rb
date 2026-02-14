FactoryBot.define do
  factory :tag do
    name { Faker::Lorem.unique.word.downcase }
  end
end
