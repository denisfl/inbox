# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_event do
    title { Faker::Lorem.sentence(word_count: 3) }
    starts_at { 1.hour.from_now }
    ends_at { 2.hours.from_now }
    status { "confirmed" }
    source { "manual" }
    all_day { false }

    trait :google do
      source { "google" }
      google_event_id { "google_#{SecureRandom.hex(10)}" }
      html_link { "https://calendar.google.com/event/#{google_event_id}" }
    end

    trait :all_day do
      all_day { true }
      starts_at { Date.current.beginning_of_day }
      ends_at { Date.current.end_of_day }
    end

    trait :today do
      starts_at { Time.current.change(hour: 14) }
      ends_at { Time.current.change(hour: 15) }
    end

    trait :tomorrow do
      starts_at { 1.day.from_now.change(hour: 10) }
      ends_at { 1.day.from_now.change(hour: 11) }
    end

    trait :past do
      starts_at { 1.day.ago }
      ends_at { 1.day.ago + 1.hour }
    end

    trait :needs_reminder do
      starts_at { 5.minutes.from_now }
      ends_at { 65.minutes.from_now }
      reminded_at { nil }
    end

    trait :already_reminded do
      starts_at { 15.minutes.from_now }
      reminded_at { 5.minutes.ago }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :ical do
      source { "ical" }
    end
  end
end
