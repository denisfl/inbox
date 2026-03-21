FactoryBot.define do
  factory :backup_record do
    status { "completed" }
    started_at { 1.hour.ago }
    completed_at { 30.minutes.ago }
    size_bytes { 1024 * 100 }
    storage_path { "/app/storage/backups/backup_20260321_030000.sql.gz" }
    storage_type { "local" }

    trait :running do
      status { "running" }
      completed_at { nil }
      size_bytes { nil }
      storage_path { nil }
    end

    trait :failed do
      status { "failed" }
      error_message { "RuntimeError: SQLite dump failed" }
    end

    trait :old do
      started_at { 45.days.ago }
      completed_at { 45.days.ago }
      created_at { 45.days.ago }
    end
  end
end
