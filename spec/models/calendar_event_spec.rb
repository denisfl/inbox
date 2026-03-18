# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalendarEvent, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:calendar_event_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:calendar_event_tags) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_inclusion_of(:status).in_array(CalendarEvent::STATUSES) }
    it { is_expected.to validate_inclusion_of(:source).in_array(CalendarEvent::SOURCES) }

    context "google_event_id uniqueness" do
      subject { create(:calendar_event, :google) }
      it { is_expected.to validate_uniqueness_of(:google_event_id) }
    end

    context "google source requires google_event_id" do
      it "is invalid without google_event_id when source is google" do
        event = build(:calendar_event, :google, google_event_id: nil)
        expect(event).not_to be_valid
        expect(event.errors[:google_event_id]).to be_present
      end
    end
  end

  describe "callbacks" do
    describe "assign_local_uid" do
      it "assigns a uid for manual events when google_event_id is blank" do
        event = create(:calendar_event, source: "manual", google_event_id: nil)
        expect(event.google_event_id).to start_with("manual-")
      end

      it "assigns a uid for ical events when google_event_id is blank" do
        event = create(:calendar_event, source: "ical", google_event_id: nil)
        expect(event.google_event_id).to start_with("ical-")
      end

      it "does not override existing google_event_id" do
        event = create(:calendar_event, :google)
        expect(event.google_event_id).to start_with("google_")
      end
    end

    describe "normalize_event_times" do
      it "normalizes all_day event to beginning and end of day" do
        event = create(:calendar_event, :all_day)
        expect(event.starts_at).to eq(event.starts_at.beginning_of_day)
        expect(event.ends_at).to be_within(1.second).of(event.starts_at.end_of_day)
      end

      it "corrects ends_at if it is before starts_at" do
        starts = 2.hours.from_now
        event = create(:calendar_event, starts_at: starts, ends_at: starts - 1.hour)
        expect(event.ends_at).to be_within(0.001.seconds).of(starts + 1.hour)
      end

      it "corrects ends_at if it equals starts_at" do
        starts = 2.hours.from_now
        event = create(:calendar_event, starts_at: starts, ends_at: starts)
        expect(event.ends_at).to be_within(0.001.seconds).of(starts + 1.hour)
      end
    end
  end

  describe "scopes" do
    describe ".confirmed" do
      let!(:confirmed) { create(:calendar_event, status: "confirmed") }
      let!(:cancelled) { create(:calendar_event, :cancelled) }

      it "returns only confirmed events" do
        expect(CalendarEvent.confirmed).to include(confirmed)
        expect(CalendarEvent.confirmed).not_to include(cancelled)
      end
    end

    describe ".google" do
      let!(:google_event) { create(:calendar_event, :google) }
      let!(:manual_event) { create(:calendar_event, source: "manual") }

      it "returns only google events" do
        expect(CalendarEvent.google).to include(google_event)
        expect(CalendarEvent.google).not_to include(manual_event)
      end
    end

    describe ".manual" do
      let!(:manual_event) { create(:calendar_event, source: "manual") }
      let!(:google_event) { create(:calendar_event, :google) }

      it "returns only manual events" do
        expect(CalendarEvent.manual).to include(manual_event)
        expect(CalendarEvent.manual).not_to include(google_event)
      end
    end

    describe ".ical" do
      let!(:ical_event) { create(:calendar_event, :ical) }
      let!(:manual_event) { create(:calendar_event, source: "manual") }

      it "returns only ical events" do
        expect(CalendarEvent.ical).to include(ical_event)
        expect(CalendarEvent.ical).not_to include(manual_event)
      end
    end

    describe ".upcoming" do
      let!(:future_event) { create(:calendar_event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now) }
      let!(:past_event) { create(:calendar_event, :past) }
      let!(:cancelled_event) { create(:calendar_event, :cancelled, starts_at: 1.hour.from_now) }

      it "returns only future confirmed events" do
        expect(CalendarEvent.upcoming).to include(future_event)
        expect(CalendarEvent.upcoming).not_to include(past_event)
        expect(CalendarEvent.upcoming).not_to include(cancelled_event)
      end
    end

    describe ".today" do
      let!(:today_event) { create(:calendar_event, :today) }
      let!(:tomorrow_event) { create(:calendar_event, :tomorrow) }

      it "returns only today's confirmed events" do
        expect(CalendarEvent.today).to include(today_event)
        expect(CalendarEvent.today).not_to include(tomorrow_event)
      end
    end

    describe ".tomorrow" do
      let!(:today_event) { create(:calendar_event, :today) }
      let!(:tomorrow_event) { create(:calendar_event, :tomorrow) }

      it "returns only tomorrow's confirmed events" do
        expect(CalendarEvent.tomorrow).to include(tomorrow_event)
        expect(CalendarEvent.tomorrow).not_to include(today_event)
      end
    end

    describe ".this_week" do
      let!(:this_week_event) { create(:calendar_event, starts_at: 2.days.from_now, ends_at: 2.days.from_now + 1.hour) }
      let!(:far_future_event) { create(:calendar_event, starts_at: 2.weeks.from_now, ends_at: 2.weeks.from_now + 1.hour) }

      it "returns events within the next 7 days" do
        expect(CalendarEvent.this_week).to include(this_week_event)
        expect(CalendarEvent.this_week).not_to include(far_future_event)
      end
    end

    describe ".in_range" do
      let!(:in_range) { create(:calendar_event, starts_at: 3.days.from_now, ends_at: 3.days.from_now + 1.hour) }
      let!(:out_of_range) { create(:calendar_event, starts_at: 30.days.from_now, ends_at: 30.days.from_now + 1.hour) }

      it "returns events within the specified range" do
        from = 2.days.from_now.beginning_of_day
        to = 5.days.from_now.end_of_day

        expect(CalendarEvent.in_range(from, to)).to include(in_range)
        expect(CalendarEvent.in_range(from, to)).not_to include(out_of_range)
      end
    end

    describe ".needs_reminder" do
      let!(:needs_reminder) { create(:calendar_event, :needs_reminder) }
      let!(:already_reminded) { create(:calendar_event, :already_reminded) }
      let!(:far_future) { create(:calendar_event, starts_at: 2.hours.from_now, ends_at: 3.hours.from_now) }

      it "returns events starting in 10-30 min that have not been reminded" do
        expect(CalendarEvent.needs_reminder).to include(needs_reminder)
        expect(CalendarEvent.needs_reminder).not_to include(already_reminded)
        expect(CalendarEvent.needs_reminder).not_to include(far_future)
      end
    end
  end

  describe "instance methods" do
    describe "#duration_minutes" do
      it "returns duration in minutes" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 90.minutes)
        expect(event.duration_minutes).to eq(90)
      end

      it "returns nil for all-day events" do
        event = build(:calendar_event, :all_day)
        expect(event.duration_minutes).to be_nil
      end

      it "returns nil when ends_at is blank" do
        event = build(:calendar_event, ends_at: nil)
        expect(event.duration_minutes).to be_nil
      end
    end

    describe "#duration_label" do
      it "returns minutes label for short events" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 30.minutes)
        expect(event.duration_label).to eq("30m")
      end

      it "returns hours label for longer events" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 2.hours)
        expect(event.duration_label).to eq("2h")
      end

      it "returns combined label for mixed durations" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 90.minutes)
        expect(event.duration_label).to eq("1h 30m")
      end
    end

    describe "#display_color" do
      it "returns mapped color for known Google color IDs" do
        event = build(:calendar_event, color: "1")
        expect(event.display_color).to eq("#a4bdfc")
      end

      it "returns default color for unknown color IDs" do
        event = build(:calendar_event, color: "99")
        expect(event.display_color).to eq("#5484ed")
      end

      it "returns default color when color is nil" do
        event = build(:calendar_event, color: nil)
        expect(event.display_color).to eq("#5484ed")
      end
    end

    describe "#time_label" do
      it "returns 'All day' for all-day events" do
        event = build(:calendar_event, :all_day)
        expect(event.time_label).to eq("All day")
      end

      it "returns formatted time for timed events" do
        event = build(:calendar_event, starts_at: Time.current.change(hour: 14, min: 30))
        expect(event.time_label).to eq("14:30")
      end
    end

    describe "#local?" do
      it "returns true for manual events" do
        event = build(:calendar_event, source: "manual")
        expect(event.local?).to be true
      end

      it "returns true for ical events" do
        event = build(:calendar_event, source: "ical")
        expect(event.local?).to be true
      end

      it "returns false for google events" do
        event = build(:calendar_event, :google)
        expect(event.local?).to be false
      end
    end

    describe "#past?" do
      it "returns true when ends_at is in the past" do
        event = build(:calendar_event, starts_at: 2.hours.ago, ends_at: 30.minutes.ago)
        expect(event.past?).to be true
      end

      it "returns true using starts_at when ends_at is nil" do
        event = build(:calendar_event, starts_at: 1.hour.ago, ends_at: nil)
        expect(event.past?).to be true
      end

      it "returns false when ends_at is in the future (ongoing event)" do
        event = build(:calendar_event, starts_at: 1.hour.ago, ends_at: 30.minutes.from_now)
        expect(event.past?).to be false
      end

      it "returns false for all-day events" do
        event = build(:calendar_event, :all_day)
        expect(event.past?).to be false
      end

      it "returns false for future events" do
        event = build(:calendar_event, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now)
        expect(event.past?).to be false
      end
    end

    describe "#grid_row_start" do
      it "returns 1 for an event at 07:00" do
        event = build(:calendar_event, starts_at: Time.current.change(hour: 7, min: 0))
        expect(event.grid_row_start).to eq(1)
      end

      it "returns correct row for 10:30" do
        event = build(:calendar_event, starts_at: Time.current.change(hour: 10, min: 30))
        expect(event.grid_row_start).to eq(8) # (10-7)*2 + 1 + 1 for 30min offset
      end

      it "clamps to row 1 for events before 07:00" do
        event = build(:calendar_event, starts_at: Time.current.change(hour: 5, min: 0))
        expect(event.grid_row_start).to eq(1)
      end

      it "returns nil for all-day events" do
        event = build(:calendar_event, :all_day)
        expect(event.grid_row_start).to be_nil
      end
    end

    describe "#grid_row_span" do
      it "returns span based on duration" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 90.minutes)
        expect(event.grid_row_span).to eq(3)
      end

      it "returns 1 for all-day events" do
        event = build(:calendar_event, :all_day)
        expect(event.grid_row_span).to eq(1)
      end

      it "returns 1 when ends_at is nil" do
        event = build(:calendar_event, ends_at: nil)
        expect(event.grid_row_span).to eq(1)
      end

      it "returns minimum 1 for very short events" do
        event = build(:calendar_event, starts_at: Time.current, ends_at: Time.current + 5.minutes)
        expect(event.grid_row_span).to eq(1)
      end
    end
  end

  describe ".grouped_by_day" do
    it "groups events by date" do
      today_event = create(:calendar_event, :today)
      tomorrow_event = create(:calendar_event, :tomorrow)

      grouped = CalendarEvent.grouped_by_day([ today_event, tomorrow_event ])

      expect(grouped.keys).to contain_exactly(Date.current, Date.current + 1.day)
      expect(grouped[Date.current]).to eq([ today_event ])
      expect(grouped[Date.current + 1.day]).to eq([ tomorrow_event ])
    end
  end
end
