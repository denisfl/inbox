# frozen_string_literal: true

class CalendarEventsController < ApplicationController
  # GET /calendar/events/new
  def new
    @event = CalendarEvent.new(
      starts_at: parse_default_date,
      ends_at:   parse_default_date + 1.hour,
      source:    "manual",
      status:    "confirmed"
    )
  end

  # POST /calendar/events
  def create
    @event = CalendarEvent.new(event_params)
    @event.source = "manual"
    @event.status = "confirmed"

    if @event.save
      redirect_to calendar_path(date: @event.starts_at.to_date), notice: "Event created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /calendar/events/:id
  def destroy
    @event = CalendarEvent.find(params[:id])

    unless @event.local?
      redirect_to calendar_path, alert: "Google Calendar events cannot be deleted here"
      return
    end

    @event.destroy!
    redirect_to calendar_path, notice: "Event deleted", status: :see_other
  end

  # GET /calendar/events/:id/edit
  def edit
    @event = CalendarEvent.find(params[:id])

    unless @event.local?
      redirect_to calendar_path, alert: "Google Calendar events cannot be edited here"
      nil
    end
  end

  # PATCH /calendar/events/:id
  def update
    @event = CalendarEvent.find(params[:id])

    unless @event.local?
      redirect_to calendar_path, alert: "Google Calendar events cannot be edited here"
      return
    end

    @event.assign_attributes(event_params)

    if @event.save
      redirect_to calendar_path(date: @event.starts_at.to_date), notice: "Event updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /calendar/import
  def import_ical
    file = params[:ical_file]

    unless file.present?
      redirect_to calendar_path, alert: "Please select an .ics file"
      return
    end

    unless file.content_type.in?(%w[text/calendar application/ics]) ||
           file.original_filename.to_s.end_with?(".ics")
      redirect_to calendar_path, alert: "Invalid file format. Please upload an .ics file"
      return
    end

    imported = import_from_ical(file.read)
    redirect_to calendar_path, notice: "Imported #{imported} event(s)"
  rescue Icalendar::InvalidPropertyValue, StandardError => e
    redirect_to calendar_path, alert: "Import failed: #{e.message}"
  end

  private

  def event_params
    params.require(:calendar_event).permit(
      :title, :description, :starts_at, :ends_at, :all_day, :color
    )
  end

  def parse_default_date
    if params[:date].present?
      parsed = begin
        Time.zone.parse(params[:date])
      rescue ArgumentError
        nil
      end
      parsed || Time.current
    else
      Time.current.change(min: 0) + 1.hour
    end
  end

  def import_from_ical(ics_content)
    require "icalendar"

    calendars = Icalendar::Calendar.parse(ics_content)
    return 0 if calendars.empty?

    imported = 0

    calendars.each do |cal|
      cal.events.each do |vevent|
        uid = vevent.uid.to_s.presence || SecureRandom.uuid
        ical_id = "ical-#{uid}"

        # Skip if already imported (idempotent)
        next if CalendarEvent.exists?(google_event_id: ical_id)

        starts_at = normalize_ical_time(vevent.dtstart)
        next unless starts_at # skip events without start time

        ends_at   = normalize_ical_time(vevent.dtend)
        all_day   = ical_date_only?(vevent.dtstart)
        yearly    = ical_yearly_recurrence?(vevent)

        # For yearly recurring events (birthdays, anniversaries):
        # project the date into the current or next year so it appears on the calendar.
        if yearly && all_day
          starts_at, ends_at = project_yearly_event(vevent.dtstart, vevent.dtend)
        end

        # Build description — append original year for birthdays if known
        description = vevent.description.to_s.presence
        if yearly
          original_year = extract_ical_year(vevent.dtstart)
          if original_year && original_year > 1900 && original_year < Time.current.year
            age = Time.current.year - original_year
            year_note = "Born: #{original_year} (#{age})"
            description = [ description, year_note ].compact.join("\n\n")
          end
        end

        CalendarEvent.create!(
          google_event_id: ical_id,
          title:           vevent.summary.to_s.presence || "(No title)",
          description:     description,
          starts_at:       starts_at,
          ends_at:         ends_at,
          all_day:         all_day,
          status:          "confirmed",
          source:          "ical"
        )

        imported += 1
      end
    end

    imported
  end

  # Detect VALUE=DATE (all-day) vs VALUE=DATE-TIME.
  # icalendar gem v2.12: Values::Date inherits DateTime, so is_a?(Date) && !is_a?(DateTime) is always false.
  # Instead, check the Icalendar-specific class name or the ical_params hash.
  def ical_date_only?(dt)
    return false if dt.nil?

    # Check class name (Icalendar::Values::Date vs Icalendar::Values::DateTime)
    return true if dt.class.name == "Icalendar::Values::Date"

    # Fallback: check VALUE param
    if dt.respond_to?(:ical_params) && dt.ical_params.is_a?(Hash)
      value_param = dt.ical_params["VALUE"] || dt.ical_params[:VALUE] ||
                    dt.ical_params["value"] || dt.ical_params[:value]
      return true if value_param.to_s.casecmp("DATE").zero?
    end

    # Last resort: pure Date (not DateTime/Time)
    dt.is_a?(Date) && !dt.is_a?(DateTime) && !dt.is_a?(Time)
  end

  # Check if the event has RRULE:FREQ=YEARLY
  def ical_yearly_recurrence?(vevent)
    return false unless vevent.respond_to?(:rrule) && vevent.rrule.present?

    vevent.rrule.any? do |rule|
      rule_str = rule.respond_to?(:value_ical) ? rule.value_ical : rule.to_s
      rule_str.to_s.include?("FREQ=YEARLY")
    end
  end

  # Extract the year from a DTSTART value (for birth year annotation)
  def extract_ical_year(dt)
    return nil if dt.nil?
    year = dt.respond_to?(:year) ? dt.year : nil
    year
  end

  # Project a yearly all-day event into the current or next year.
  # Returns [starts_at, ends_at] as Time in current timezone.
  def project_yearly_event(dtstart, dtend)
    month = dtstart.respond_to?(:month) ? dtstart.month : dtstart.to_date.month
    day   = dtstart.respond_to?(:day)   ? dtstart.day   : dtstart.to_date.day

    today = Date.current
    this_year_date = safe_date(today.year, month, day)

    target_date = if this_year_date && this_year_date >= today
                    this_year_date
    else
                    safe_date(today.year + 1, month, day) || this_year_date
    end

    return [ nil, nil ] unless target_date

    starts_at = target_date.beginning_of_day.in_time_zone
    ends_at   = target_date.end_of_day.in_time_zone

    [ starts_at, ends_at ]
  end

  # Safely construct a Date, handling invalid dates (e.g., Feb 29 in non-leap years)
  def safe_date(year, month, day)
    Date.new(year, month, day)
  rescue ArgumentError
    # Feb 29 in a non-leap year -> use Feb 28
    day == 29 && month == 2 ? Date.new(year, 2, 28) : nil
  end

  def normalize_ical_time(dt)
    return nil if dt.nil?

    # Icalendar gem values inherit from DateTime/Date but handle via to_time
    if dt.respond_to?(:to_time)
      dt.to_time&.in_time_zone
    elsif dt.respond_to?(:to_datetime)
      dt.to_datetime.to_time&.in_time_zone
    else
      Time.zone.parse(dt.to_s) rescue nil
    end
  end
end
