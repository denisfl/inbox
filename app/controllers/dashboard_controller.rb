# frozen_string_literal: true

class DashboardController < ApplicationController
  def index
    # ── Tasks today (active due today + pinned) ──────────────────────────────
    @tasks_today = Task.today.ordered
    @tasks_completed_today = Task.where(completed: true, due_date: Date.current)
                                 .order(completed_at: :desc).limit(3)

    # ── Events today ─────────────────────────────────────────────────────────
    @events_today = CalendarEvent.today

    # ── Recent documents ─────────────────────────────────────────────────────
    @recent_documents = Document.includes(:blocks, :tags)
                                .order(created_at: :desc).limit(5)

    # ── Stats strip ──────────────────────────────────────────────────────────
    next_event = CalendarEvent.today
                              .where("starts_at > ?", Time.current)
                              .order(:starts_at).first

    @stats = {
      tasks_today:   Task.today.count,
      tasks_overdue: Task.overdue.count,
      events_today:  CalendarEvent.today.count,
      next_event:    next_event,
      new_notes:     Document.where("created_at >= ?", 1.day.ago).count,
      inbox_count:   @sidebar_counts[:documents]
    }

    # ── Upcoming events (tomorrow + rest of week) ────────────────────────────
    @events_tomorrow = CalendarEvent.tomorrow
    @events_week     = CalendarEvent.confirmed
                         .where(starts_at: 2.days.from_now.beginning_of_day..Time.current.end_of_week.end_of_day)
                         .order(:starts_at)
                         .limit(5)
    @events_next_week = CalendarEvent.confirmed
                          .where(starts_at: (Time.current.end_of_week + 1.day).beginning_of_day..
                                            (Time.current.end_of_week + 7.days).end_of_day)
                          .order(:starts_at)
                          .limit(5)

    # ── Contextual greeting subtitle ────────────────────────────────────────
    @greeting_subtitle = build_greeting_subtitle

    # ── Activity feed (assembled from existing records) ──────────────────────
    @activities = build_activity_feed

    # ── Mini calendar ────────────────────────────────────────────────────────
    @cal_date = if params[:cal_month].present?
                  Date.strptime(params[:cal_month], "%Y-%m")
    else
                  Date.current
    end
    @cal_month_start = @cal_date.beginning_of_month
    @cal_month_end   = @cal_date.end_of_month
    @cal_event_days  = CalendarEvent
                         .in_range(@cal_month_start.beginning_of_day, @cal_month_end.end_of_day)
                         .pluck(:starts_at)
                         .map { |t| t.to_date.day }
                         .uniq
                         .to_set
  end

  # POST /quick_capture
  def quick_capture
    content = params[:content].to_s.strip
    if content.blank?
      redirect_to root_path, alert: "Enter some text"
      return
    end

    case params[:capture_type]
    when "note"
      doc = Document.create!(title: content.truncate(80))
      # Auto-tag as web-created
      web_tag = Tag.find_or_create_by!(name: "web")
      doc.tags << web_tag unless doc.tags.include?(web_tag)
      block = doc.blocks.new(block_type: "text", position: 0)
      block.content_hash = { text: content }
      block.save!
      redirect_to edit_document_path(doc), notice: "Note created", status: :see_other

    when "task"
      Task.create!(title: content, priority: "mid", due_date: Date.current)
      redirect_to root_path, notice: "Task created", status: :see_other

    when "event"
      CalendarEvent.create!(
        title:    content,
        starts_at: 1.hour.from_now,
        ends_at:   2.hours.from_now,
        source:   "manual",
        status:   "confirmed"
      )
      redirect_to root_path, notice: "Event created", status: :see_other

    else
      redirect_to root_path, alert: "Unknown type"
    end
  end

  private

  # Build a unified activity feed from Documents, Tasks, and CalendarEvents
  def build_activity_feed
    activities = []

    # Recent documents (last 14 days)
    Document.where("created_at > ?", 14.days.ago)
            .includes(:tags)
            .order(created_at: :desc).limit(10).each do |doc|
      title_esc = ERB::Util.html_escape(doc.title.truncate(40))
      tag_names = doc.tags.map(&:name)
      text = if tag_names.include?("telegram")
               "Telegram → <strong>#{title_esc}</strong>"
      elsif tag_names.include?("audio")
               "Voice note → <strong>#{title_esc}</strong>"
      else
               "Note created: <strong>#{title_esc}</strong>"
      end
      activities << { icon_type: icon_for_tags(tag_names), text: text, time: doc.created_at }
    end

    # Recently created tasks (last 14 days)
    Task.where(completed: false)
        .where("created_at > ?", 14.days.ago)
        .order(created_at: :desc)
        .limit(5)
        .each do |task|
      title_esc = ERB::Util.html_escape(task.title.truncate(40))
      activities << {
        icon_type: :task_new,
        text: "Task added: <strong>#{title_esc}</strong>",
        time: task.created_at
      }
    end

    # Recently completed tasks (last 14 days)
    Task.completed
        .where("completed_at > ?", 14.days.ago)
        .order(completed_at: :desc)
        .limit(5)
        .each do |task|
      title_esc = ERB::Util.html_escape(task.title.truncate(40))
      activities << {
        icon_type: :task_done,
        text: "Task completed: <strong>#{title_esc}</strong>",
        time: task.completed_at
      }
    end

    # Google Calendar syncs (last 14 days)
    CalendarEvent.google
                 .where.not(synced_at: nil)
                 .where("synced_at > ?", 14.days.ago)
                 .select("DATE(synced_at) as sync_date, COUNT(*) as cnt, MAX(synced_at) as last_sync")
                 .group("DATE(synced_at)")
                 .order("sync_date DESC")
                 .limit(3)
                 .each do |row|
      sync_time = row.last_sync.is_a?(String) ? Time.zone.parse(row.last_sync) : row.last_sync
      activities << {
        icon_type: :calendar,
        text: "GCal synced — <strong>#{row.cnt} events</strong>",
        time: sync_time
      }
    end

    # Calendar events that started recently (past events today)
    CalendarEvent.where("starts_at BETWEEN ? AND ?", Time.current.beginning_of_day, Time.current)
                 .order(starts_at: :desc)
                 .limit(3)
                 .each do |event|
      title_esc = ERB::Util.html_escape(event.title.truncate(40))
      activities << {
        icon_type: :calendar,
        text: "Event started: <strong>#{title_esc}</strong>",
        time: event.starts_at
      }
    end

    activities.sort_by { |a| -(a[:time] || Time.at(0)).to_i }.first(15)
  end

  def icon_for_tags(tag_names)
    if tag_names.include?("telegram")
      :telegram
    elsif tag_names.include?("audio")
      :voice
    else
      :note
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def build_greeting_subtitle
    hour          = Time.current.hour
    wday          = Date.current.wday # 0=Sun, 1=Mon … 5=Fri, 6=Sat
    tasks_today   = @stats[:tasks_today]
    overdue       = @stats[:tasks_overdue]
    events_today  = @stats[:events_today]
    inbox         = @stats[:inbox_count]

    # Priority: overdue > busy day > clear day > day-of-week flavor > generic
    if overdue > 3
      return "You have #{overdue} overdue tasks — might be worth a quick triage."
    end

    if overdue > 0 && tasks_today > 0
      return "#{tasks_today} tasks today, plus #{overdue} overdue — let's sort that out."
    end

    if overdue > 0
      return "#{overdue} overdue #{'task'.pluralize(overdue)} waiting for you."
    end

    if tasks_today == 0 && events_today == 0
      case wday
      when 0, 6 then return "No tasks, no meetings — enjoy your weekend."
      when 5
        return hour >= 16 ? "Nothing left for today. Almost Friday-done." : "Clean slate today — nice."
      else return "Nothing on the agenda — a blank canvas kind of day."
      end
    end

    if tasks_today > 5 && events_today > 3
      return "Packed day ahead — #{tasks_today} tasks and #{events_today} events."
    end

    if events_today > 3
      return "Meeting-heavy day — #{events_today} events lined up."
    end

    # Day-of-week flavor
    case wday
    when 1
      return "Monday. #{tasks_today} tasks to kick things off."
    when 5
      if hour >= 16
        return "Almost there — #{tasks_today} tasks left before the weekend."
      else
        return "Friday. #{tasks_today} tasks and the weekend is in sight."
      end
    when 0, 6
      return "Weekend mode. #{tasks_today} #{'task'.pluralize(tasks_today)} if you feel like it."
    end

    # Late night
    if hour >= 23 || hour < 5
      return "Burning the midnight oil? #{tasks_today} tasks on the board."
    end

    # Generic with inbox mention
    if inbox > 5
      return "#{tasks_today} tasks today and #{inbox} items in your inbox."
    end

    "#{tasks_today} tasks and #{events_today} #{'event'.pluralize(events_today)} — here's your day."
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
