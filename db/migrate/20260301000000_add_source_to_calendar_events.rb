# frozen_string_literal: true

class AddSourceToCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    # Allow manual and iCal events (no google_event_id required)
    change_column_null :calendar_events, :google_event_id, true

    # Source: google (synced from GCal), manual (created in UI), ical (imported)
    add_column :calendar_events, :source, :string, null: false, default: "google"
    add_index  :calendar_events, :source
  end
end
