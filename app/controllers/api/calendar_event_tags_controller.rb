# frozen_string_literal: true

class Api::CalendarEventTagsController < Api::BaseController
  before_action :set_calendar_event

  def create
    name = params[:name]&.downcase&.strip
    return render json: { error: "Tag name is required" }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by!(name: name)
    @calendar_event.tags << tag unless @calendar_event.tags.include?(tag)
    render json: { tag: { name: tag.name, color: tag.color } }, status: :created
  end

  def destroy
    tag = Tag.find_by!(name: params[:name].downcase)
    @calendar_event.tags.delete(tag)
    head :no_content
  end

  private

  def set_calendar_event
    @calendar_event = CalendarEvent.find(params[:calendar_event_id])
  end
end
