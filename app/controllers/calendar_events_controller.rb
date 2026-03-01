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
      return
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
      Time.zone.parse(params[:date]) rescue Time.current
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

        ends_at  = normalize_ical_time(vevent.dtend)
        all_day  = vevent.dtstart.is_a?(Date) && !vevent.dtstart.is_a?(DateTime)

        CalendarEvent.create!(
          google_event_id: ical_id,
          title:           vevent.summary.to_s.presence || "(No title)",
          description:     vevent.description.to_s.presence,
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

  def normalize_ical_time(dt)
    return nil if dt.nil?

    # Icalendar gem values inherit from DateTime/Date but handle via to_time
    if dt.respond_to?(:to_time)
      dt.to_time.in_time_zone
    elsif dt.respond_to?(:to_datetime)
      dt.to_datetime.to_time.in_time_zone
    else
      Time.zone.parse(dt.to_s) rescue nil
    end
  end
end
