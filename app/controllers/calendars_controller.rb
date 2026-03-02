# frozen_string_literal: true

class CalendarsController < ApplicationController
  # GET /calendar/widget  (Turbo Frame — embeddable in sidebar)
  def widget
    @today_events    = CalendarEvent.today
    @tomorrow_events = CalendarEvent.tomorrow
    @week_events     = CalendarEvent.this_week
                         .where.not(starts_at: Time.current.beginning_of_day..Time.current.end_of_day)
                         .where.not(starts_at: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
                         .limit(5)
    @today_tasks     = Task.today
  end

  # GET /calendar
  def index
    @view_date = parse_view_date
    @filter    = %w[all notes events tasks].include?(params[:filter]) ? params[:filter] : "events"
    @view_mode = %w[agenda week month].include?(params[:view]) ? params[:view] : "agenda"

    # Compute date range based on view mode
    case @view_mode
    when "week"
      @range_start = @view_date.beginning_of_week(:monday)
      @range_end   = @range_start + 6.days
    when "month"
      @range_start = @view_date.beginning_of_month
      @range_end   = @view_date.end_of_month
    else # agenda
      @range_start = params[:date].present? ? @view_date : Date.today
      @range_end   = @range_start + 4.weeks
    end

    # Calendar events in range (confirmed only)
    cal_events = %w[notes tasks].include?(@filter) ? CalendarEvent.none :
      CalendarEvent.includes(:tags).in_range(@range_start.beginning_of_day, @range_end.end_of_day)

    # Inbox documents created in range (for unified timeline)
    inbox_docs = %w[events tasks].include?(@filter) ? Document.none :
      Document.where(created_at: @range_start.beginning_of_day..@range_end.end_of_day)
              .order(created_at: :asc)

    # Tasks with due_date in range
    cal_tasks = %w[notes events].include?(@filter) ? Task.none :
      Task.in_date_range(@range_start, @range_end)

    # Build unified day-keyed timeline
    @timeline = build_timeline(cal_events, inbox_docs, cal_tasks)

    # Days that have any entry (for mini-month dots)
    @days_with_content = @timeline.keys.to_set

    # Week view: build hour-indexed structure
    if @view_mode == "week"
      @week_days = (@range_start..@range_end).to_a
      @week_events_by_day = {}
      @week_days.each do |day|
        @week_events_by_day[day] = (@timeline[day] || [])
      end
    end

    # Mini-month navigation: show the month that contains @view_date
    @month_start = @view_date.beginning_of_month
    @month_end   = @view_date.end_of_month
  end

  private

  def parse_view_date
    if params[:date].present?
      Date.parse(params[:date]) rescue Date.today
    else
      Date.today
    end
  end

  # Returns Hash<Date, Array<{type:, record:}>> sorted by date
  def build_timeline(cal_events, inbox_docs, cal_tasks = Task.none)
    timeline = Hash.new { |h, k| h[k] = [] }

    cal_events.each do |ev|
      timeline[ev.starts_at.to_date] << { type: :event, record: ev }
    end

    inbox_docs.each do |doc|
      timeline[doc.created_at.to_date] << { type: :document, record: doc }
    end

    cal_tasks.each do |task|
      timeline[task.due_date] << { type: :task, record: task }
    end

    # Sort each day's entries: events first (by time), tasks, then documents
    timeline.each do |date, entries|
      timeline[date] = entries.sort_by do |entry|
        case entry[:type]
        when :event    then [ 0, entry[:record].starts_at ]
        when :task     then [ 1, entry[:record].due_time || Time.current.end_of_day ]
        when :document then [ 2, entry[:record].created_at ]
        end
      end
    end

    timeline.sort.to_h
  end
end
