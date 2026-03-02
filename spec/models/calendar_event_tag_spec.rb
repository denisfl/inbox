# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalendarEventTag, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:calendar_event) }
    it { is_expected.to belong_to(:tag) }
  end

  describe "validations" do
    subject { create(:calendar_event_tag) }
    it { is_expected.to validate_uniqueness_of(:calendar_event_id).scoped_to(:tag_id) }
  end
end
