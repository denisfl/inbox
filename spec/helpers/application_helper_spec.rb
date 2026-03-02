# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#back_link" do
    it "renders a link with arrow_left icon and label" do
      html = helper.back_link("/tasks", "Tasks")
      expect(html).to include("Tasks")
      expect(html).to include('class="back-link"')
    end
  end

  describe "#render_markdown" do
    it "returns empty string for blank text" do
      expect(helper.render_markdown("")).to eq("")
      expect(helper.render_markdown(nil)).to eq("")
    end

    it "renders bold markdown" do
      result = helper.render_markdown("**bold**")
      expect(result).to include("<strong>bold</strong>")
    end

    it "preserves task-list markup in output" do
      md = "- [x] Done\n- [ ] Not done"
      result = helper.render_markdown(md)
      expect(result).to include("Done")
      expect(result).to include("Not done")
    end

    it "returns html_safe string" do
      expect(helper.render_markdown("hello")).to be_html_safe
    end
  end
end
