# frozen_string_literal: true

FactoryBot.define do
  factory :calendar_event_tag do
    association :calendar_event
    association :tag
  end
end
