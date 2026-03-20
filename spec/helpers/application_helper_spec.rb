# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#back_link" do
    it "renders a link with arrow_left icon and label" do
      html = helper.back_link("/tasks", "Tasks")
      expect(html).to include("Tasks")
      expect(html).to include('class="back-link"')
      expect(html).to include("history.back()")
    end
  end
end
