# frozen_string_literal: true

namespace :calendar do
  desc "Re-project iCal events with old dates (birthdays) to the current/next year"
  task fix_ical_dates: :environment do
    current_year = Time.current.year
    fixed = 0

    CalendarEvent.ical.where("starts_at < ?", Date.new(current_year - 1, 1, 1)).find_each do |event|
      original_month = event.starts_at.month
      original_day   = event.starts_at.day
      original_year  = event.starts_at.year

      # Project to current or next year
      today = Date.current
      target_date = begin
        this_year = Date.new(today.year, original_month, original_day)
        this_year >= today ? this_year : Date.new(today.year + 1, original_month, original_day)
      rescue ArgumentError
        # Feb 29 in non-leap year -> use Feb 28
        begin
          Date.new(today.year, original_month, 28)
        rescue ArgumentError
          next
        end
      end

      new_starts_at = target_date.beginning_of_day
      new_ends_at   = target_date.end_of_day

      # Add birth year to description if known and reasonable
      if original_year > 1900 && original_year < current_year
        age = current_year - original_year
        year_note = "Born: #{original_year} (#{age})"
        unless event.description.to_s.include?("Born:")
          event.description = [ event.description.presence, year_note ].compact.join("\n\n")
        end
      end

      event.update!(
        starts_at: new_starts_at,
        ends_at:   new_ends_at,
        all_day:   true
      )

      fixed += 1
      puts "Fixed: #{event.title} | #{event.starts_at.to_date}"
    end

    puts "Done. Fixed #{fixed} event(s)."
  end
end
