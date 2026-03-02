# frozen_string_literal: true

FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence(word_count: 3) }
    priority { "mid" }
    completed { false }

    trait :pinned do
      priority { "pinned" }
    end

    trait :high do
      priority { "high" }
    end

    trait :low do
      priority { "low" }
    end

    trait :completed do
      completed { true }
      completed_at { Time.current }
    end

    trait :due_today do
      due_date { Date.current }
    end

    trait :due_tomorrow do
      due_date { Date.current + 1.day }
    end

    trait :overdue do
      due_date { Date.current - 2.days }
    end

    trait :inbox do
      due_date { nil }
      priority { "mid" }
    end

    trait :recurring_daily do
      recurrence_rule { "daily" }
      due_date { Date.current }
    end

    trait :recurring_weekly do
      recurrence_rule { "weekly" }
      due_date { Date.current }
    end

    trait :recurring_monthly do
      recurrence_rule { "monthly" }
      due_date { Date.current }
    end

    trait :recurring_yearly do
      recurrence_rule { "yearly" }
      due_date { Date.current }
    end

    trait :with_tags do
      after(:create) do |task|
        tag = create(:tag)
        create(:task_tag, task: task, tag: tag)
      end
    end
  end
end
