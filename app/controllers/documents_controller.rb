class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :edit]

  def index
    documents_scope = Document.includes(:blocks, :tags)

    # Search by query
    if params[:q].present?
      query = params[:q].strip
      documents_scope = documents_scope.left_joins(:blocks)
        .where("documents.title LIKE ? OR blocks.content LIKE ?", "%#{query}%", "%#{query}%")
        .distinct
    end

    # Filter by source (telegram, api)
    if params[:source].present?
      documents_scope = documents_scope.where(source: params[:source])
    end

    # Filter by type (voice, photo)
    if params[:type].present?
      case params[:type]
      when 'voice'
        documents_scope = documents_scope.joins(:blocks)
          .where(blocks: {block_type: 'file'})
          .where("blocks.content LIKE ?", "%voice%")
          .distinct
      when 'photo'
        documents_scope = documents_scope.joins(:blocks)
          .where(blocks: {block_type: 'file'})
          .where("blocks.content LIKE ? OR blocks.content LIKE ?", "%image%", "%photo%")
          .distinct
      end
    end

    # Filter by tag
    if params[:tag].present?
      documents_scope = documents_scope.joins(:tags).where(tags: {name: params[:tag]})
    end

    # Sort
    sort_by = params[:sort] || 'updated_desc'
    case sort_by
    when 'created_desc'
      documents_scope = documents_scope.order(created_at: :desc)
    when 'created_asc'
      documents_scope = documents_scope.order(created_at: :asc)
    when 'title_asc'
      documents_scope = documents_scope.order(title: :asc)
    when 'title_desc'
      documents_scope = documents_scope.order(title: :desc)
    else # updated_desc (default)
      documents_scope = documents_scope.order(updated_at: :desc)
    end

    # Pagy pagination (20 items per page)
    @pagy, @documents = pagy(documents_scope, limit: 20)

    # Calendar widget: load upcoming events directly (no Turbo Frame needed)
    @show_calendar_widget = CalendarEvent.this_week.exists?
    if @show_calendar_widget
      @widget_today    = CalendarEvent.today
      @widget_tomorrow = CalendarEvent.tomorrow
      @widget_week     = CalendarEvent.this_week
                           .where.not(starts_at: Time.current.beginning_of_day..Time.current.end_of_day)
                           .where.not(starts_at: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
                           .limit(5)
    end
  end

  def show
    # Show document in read-only mode
  end

  def edit
    # Edit document with block editor
    @blocks = @document.blocks.ordered
  end

  def new
    # Create a new document with initial empty text block
    @document = Document.create!(
      title: "Untitled",
      source: "web"
    )

    # Create initial text block
    block = @document.blocks.new(
      block_type: "text",
      position: 0
    )
    block.content_hash = { text: "" }
    block.save!

    # Redirect to edit page with 303 status (prevents Turbo caching)
    redirect_to edit_document_path(@document), status: :see_other
  end

  private

  def set_document
    @document = Document.includes(blocks: []).find(params[:id])
  end
end
