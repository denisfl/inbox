# frozen_string_literal: true

class TagsController < ApplicationController
  def index
    tag_names = normalize_tag_params

    if tag_names.present?
      # Multi-tag combined view: show documents & tasks matching ALL selected tags
      @selected_tags = Tag.where(name: tag_names).to_a
      @documents = Document.includes(:blocks, :tags).tagged_with(tag_names).order(updated_at: :desc)
      @tasks = Task.tagged_with(tag_names).includes(:tags).order(completed: :asc, priority: :desc, position: :asc)
      @calendar_events = CalendarEvent.tagged_with(tag_names).includes(:tags).order(starts_at: :desc)
      render :filtered
    else
      @tags = Tag.alphabetical
      if params[:q].present?
        @tags = @tags.where("name LIKE ?", "%#{params[:q].strip.downcase}%")
      end
    end
  end

  def show
    @tag = Tag.find_by(name: params[:name].downcase)
    unless @tag
      redirect_to tags_path, alert: "Tag not found"
      return
    end
    @documents = @tag.documents.includes(:blocks, :tags).order(updated_at: :desc)
    @tasks = @tag.tasks.includes(:tags).order(completed: :asc, priority: :desc, position: :asc)
    @calendar_events = @tag.calendar_events.includes(:tags).order(starts_at: :desc)
  end

  private

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
