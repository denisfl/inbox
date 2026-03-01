# frozen_string_literal: true

class Api::TagsController < Api::BaseController
  def index
    tags = Tag.alphabetical
    if params[:q].present?
      tags = tags.where("name LIKE ?", "%#{params[:q].strip.downcase}%")
    end
    render json: tags.limit(20).map { |t| { name: t.name, color: t.color } }
  end
end
