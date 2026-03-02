# frozen_string_literal: true

class Api::DocumentTagsController < Api::BaseController
  before_action :set_document

  def create
    name = params[:name]&.downcase&.strip
    return render json: { error: "Tag name is required" }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by!(name: name)
    @document.tags << tag unless @document.tags.include?(tag)
    render json: { tag: { name: tag.name, color: tag.color } }, status: :created
  end

  def destroy
    tag = Tag.find_by!(name: params[:name].downcase)
    @document.tags.delete(tag)
    head :no_content
  end

  private

  def set_document
    @document = Document.find(params[:document_id])
  end
end
