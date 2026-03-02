# frozen_string_literal: true

class Api::TaskTagsController < Api::BaseController
  before_action :set_task

  def create
    name = params[:name]&.downcase&.strip
    return render json: { error: "Tag name is required" }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by!(name: name)
    @task.tags << tag unless @task.tags.include?(tag)
    render json: { tag: { name: tag.name, color: tag.color } }, status: :created
  end

  def destroy
    tag = Tag.find_by!(name: params[:name].downcase)
    @task.tags.delete(tag)
    head :no_content
  end

  private

  def set_task
    @task = Task.find(params[:task_id])
  end
end
