# frozen_string_literal: true

require "rails_helper"

RSpec.describe TaskTag, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:task) }
    it { is_expected.to belong_to(:tag) }
  end

  describe "validations" do
    subject { create(:task_tag) }
    it { is_expected.to validate_uniqueness_of(:task_id).scoped_to(:tag_id) }
  end
end
