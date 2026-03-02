class CalendarEventTag < ApplicationRecord
  belongs_to :calendar_event
  belongs_to :tag

  # Validations
  validates :calendar_event_id, uniqueness: { scope: :tag_id }
end
