# frozen_string_literal: true

class TasksController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_task, only: [ :show, :edit, :update, :destroy, :toggle ]

  # GET /tasks
  def index
    @filter = %w[today upcoming inbox all completed overdue].include?(params[:filter]) ? params[:filter] : "today"

    @tasks = case @filter
    when "today"     then Task.today.ordered
    when "upcoming"  then Task.upcoming.ordered
    when "inbox"     then Task.inbox.ordered
    when "all"       then Task.active.ordered
    when "completed" then Task.completed.order(completed_at: :desc)
    when "overdue"   then Task.overdue.ordered
    end

    # Multi-tag AND filter
    tag_names = normalize_tag_params
    if tag_names.present?
      @tasks = @tasks.tagged_with(tag_names)
      @selected_tags = Tag.where(name: tag_names).to_a
    end
    @selected_tags ||= []

    @overdue_count = Task.overdue.count
    @today_count   = Task.today.count
    @inbox_count   = Task.inbox.count
  end

  # GET /tasks/:id
  def show
  end

  # GET /tasks/new
  def new
    @task = Task.new(priority: "mid")
    @task.due_date = Date.parse(params[:due_date]) if params[:due_date].present?
  end

  # POST /tasks
  def create
    @task = Task.new(task_params)
    @task.priority ||= "mid"
    if @task.save
      redirect_to (params[:redirect_to].presence || tasks_path(filter: determine_redirect_filter)), notice: "Task created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /tasks/:id/edit
  def edit
  end

  # PATCH /tasks/:id
  def update
    if @task.update(task_params)
      redirect_to tasks_path(filter: determine_redirect_filter), notice: "Task updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    redirect_to tasks_path(filter: params[:filter]), notice: "Task deleted"
  end

  # PATCH /tasks/:id/toggle
  def toggle
    @task.toggle!

    respond_to do |format|
      format.html { redirect_back fallback_location: tasks_path }
      format.json { head :ok }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          dom_id(@task),
          partial: "tasks/task",
          locals: { task: @task }
        )
      }
    end
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :description, :due_date, :due_time, :priority, :recurrence_rule, :position)
  end

  def determine_redirect_filter
    return "today" if @task.due_today? || @task.priority == "pinned"
    return "upcoming" if @task.due_date.present? && @task.due_date > Date.current
    return "inbox" if @task.due_date.nil?
    "all"
  end

  # Normalize tag params: supports both ?tag=name (single) and ?tags[]=a&tags[]=b (multi)
  def normalize_tag_params
    if params[:tags].present?
      Array(params[:tags]).map { |t| t.to_s.strip.downcase }.reject(&:blank?)
    elsif params[:tag].present?
      [ params[:tag].to_s.strip.downcase ]
    else
      []
    end
  end
end
