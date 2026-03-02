class CreateCalendarEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_events do |t|
      # Google Calendar identifiers
      t.string   :google_event_id,    null: false
      t.string   :google_calendar_id, null: false, default: "primary"

      # Event details
      t.string   :title,     null: false
      t.text     :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean  :all_day,   null: false, default: false

      # Visual / link
      t.string :color      # Google colorId or hex
      t.string :html_link  # URL to event in Google Calendar

      # Status: "confirmed" | "tentative" | "cancelled"
      t.string :status, null: false, default: "confirmed"

      # Reminder deduplication: set when reminder was last sent
      t.datetime :reminded_at

      # Sync metadata
      t.datetime :synced_at

      t.timestamps
    end

    add_index :calendar_events, :google_event_id, unique: true
    add_index :calendar_events, :starts_at
    add_index :calendar_events, :status
    add_index :calendar_events, %i[status starts_at]
  end
end
