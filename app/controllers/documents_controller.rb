class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit]

  def index
    @documents = Document.includes(:blocks, :tags).order(updated_at: :desc)
  end

  def show
    # Show document in read-only mode
  end

  def edit
    # Edit document with block editor
    @blocks = @document.blocks.ordered
  end

  private

  def set_document
    @document = Document.includes(blocks: []).find(params[:id])
  end
end
