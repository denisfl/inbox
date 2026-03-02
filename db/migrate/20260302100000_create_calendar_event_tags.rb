class CreateCalendarEventTags < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_event_tags do |t|
      t.references :calendar_event, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_event_tags, [:calendar_event_id, :tag_id], unique: true
  end
end
