# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardHelper, type: :helper do
  describe "#time_ago_short" do
    it 'returns "—" for nil' do
      expect(helper.time_ago_short(nil)).to eq("—")
    end

    it 'returns "now" for recent time' do
      expect(helper.time_ago_short(Time.current)).to eq("now")
    end

    it 'returns minutes format' do
      expect(helper.time_ago_short(5.minutes.ago)).to eq("5m")
    end

    it 'returns hours format' do
      expect(helper.time_ago_short(3.hours.ago)).to eq("3h")
    end

    it 'returns days format' do
      expect(helper.time_ago_short(2.days.ago)).to eq("2d")
    end

    it 'returns formatted date for old times' do
      expect(helper.time_ago_short(30.days.ago)).to match(/\d+ \w+/)
    end

    it 'parses string times' do
      expect(helper.time_ago_short(5.minutes.ago.iso8601)).to eq("5m")
    end
  end

  describe "#greeting_text" do
    it 'returns "Good morning" for morning hours' do
      travel_to Time.current.change(hour: 8) do
        expect(helper.greeting_text).to eq("Good morning")
      end
    end

    it 'returns "Good afternoon" for afternoon hours' do
      travel_to Time.current.change(hour: 14) do
        expect(helper.greeting_text).to eq("Good afternoon")
      end
    end

    it 'returns "Good evening" for evening hours' do
      travel_to Time.current.change(hour: 20) do
        expect(helper.greeting_text).to eq("Good evening")
      end
    end

    it 'returns "Good night" for late night hours' do
      travel_to Time.current.change(hour: 2) do
        expect(helper.greeting_text).to eq("Good night")
      end
    end
  end

  describe "#tag_dot_color" do
    it 'returns tag color when present' do
      tag = build(:tag, color: "#ff0000")
      expect(helper.tag_dot_color(tag)).to eq("#ff0000")
    end

    it 'returns red for todo/task tags' do
      tag = build(:tag, name: "todo", color: nil)
      expect(helper.tag_dot_color(tag)).to eq("#d74e4e")
    end

    it 'returns yellow for idea tags' do
      tag = build(:tag, name: "idea", color: nil)
      expect(helper.tag_dot_color(tag)).to eq("#b08d00")
    end

    it 'returns red for urgent tags' do
      tag = build(:tag, name: "urgent", color: nil)
      expect(helper.tag_dot_color(tag)).to eq("#d74e4e")
    end

    it 'returns blue for work tags' do
      tag = build(:tag, name: "work", color: nil)
      expect(helper.tag_dot_color(tag)).to eq("#2563eb")
    end

    it 'returns default gray for other tags' do
      tag = build(:tag, name: "misc", color: nil)
      expect(helper.tag_dot_color(tag)).to eq("#78716c")
    end
  end

  describe "#event_source_badge" do
    it 'returns GCal badge for google events' do
      event = build(:calendar_event, source: "google")
      badge = helper.event_source_badge(event)
      expect(badge[:text]).to eq("GCal")
      expect(badge[:class]).to include("gcal")
    end

    it 'returns iCal badge for ical events' do
      event = build(:calendar_event, source: "ical")
      badge = helper.event_source_badge(event)
      expect(badge[:text]).to eq("iCal")
    end

    it 'returns Manual badge for manual events' do
      event = build(:calendar_event, source: "manual")
      badge = helper.event_source_badge(event)
      expect(badge[:text]).to eq("Manual")
      expect(badge[:class]).to include("manual")
    end
  end

  describe "#cal_first_wday" do
    it 'returns the weekday offset for first day of month (Monday=0)' do
      # January 1, 2024 is a Monday => offset 0
      expect(helper.cal_first_wday(Date.new(2024, 1, 15))).to eq(0)
    end
  end
end
