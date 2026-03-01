class DocumentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_document, only: [:show, :edit, :destroy, :toggle_pinned]

  def index
    documents_scope = Document.includes(:blocks, :tags)

    # Search by query
    if params[:q].present?
      query = params[:q].strip
      documents_scope = documents_scope.left_joins(:blocks)
        .where("documents.title LIKE ? OR blocks.content LIKE ?", "%#{query}%", "%#{query}%")
        .distinct
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

    # Filter by tag(s) — supports both single tag and multi-tag AND filter
    tag_names = normalize_tag_params
    if tag_names.present?
      documents_scope = documents_scope.tagged_with(tag_names)
      @selected_tags = Tag.where(name: tag_names).to_a
    end
    @selected_tags ||= []

    # Sort — pinned documents always appear first
    documents_scope = documents_scope.pinned_first

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

    # Calendar widget: always show, with events if available
    @show_calendar_widget = true
    @widget_today    = CalendarEvent.today
    @widget_tomorrow = CalendarEvent.tomorrow
    @widget_week     = CalendarEvent.this_week
                         .where.not(starts_at: Time.current.beginning_of_day..Time.current.end_of_day)
                         .where.not(starts_at: 1.day.from_now.beginning_of_day..1.day.from_now.end_of_day)
                         .limit(5)
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

  def destroy
    @document.images.purge_later if @document.images.attached?
    @document.files.purge_later if @document.files.attached?
    @document.destroy!
    redirect_to documents_path, notice: "Note deleted", status: :see_other
  end

  def bulk_upload
    files = params[:files]

    if files.blank?
      redirect_to documents_path, alert: "No files selected"
      return
    end

    created = 0

    files.each do |file|
      title = File.basename(file.original_filename, File.extname(file.original_filename))
                  .gsub(/[_-]/, ' ')
                  .truncate(50)

      doc = Document.create!(title: title, source: 'web')

      # Create text block so the editor can work with this document
      text_block = doc.blocks.new(block_type: 'text', position: 0)
      text_block.content_hash = { text: '' }
      text_block.save!

      if file.content_type.start_with?('image/')
        block = doc.blocks.create!(block_type: 'image', position: 1, content: {}.to_json)
        block.image.attach(file)
      else
        block = doc.blocks.create!(
          block_type: 'file',
          position: 1,
          content: { filename: file.original_filename }.to_json
        )
        block.file.attach(file)
      end

      # Auto-tag based on content type
      if file.content_type.start_with?('audio/')
        auto_tag = Tag.find_or_create_by!(name: 'audio')
        doc.tags << auto_tag unless doc.tags.include?(auto_tag)
      elsif !file.content_type.start_with?('image/')
        auto_tag = Tag.find_or_create_by!(name: 'file')
        doc.tags << auto_tag unless doc.tags.include?(auto_tag)
      end

      created += 1
    end

    redirect_to documents_path, notice: "#{created} #{'document'.pluralize(created)} uploaded"
  end

  # PATCH /documents/:id/toggle_pinned
  def toggle_pinned
    @document.toggle_pinned!

    respond_to do |format|
      format.html { redirect_back fallback_location: documents_path }
      format.json { render json: { pinned: @document.pinned }, status: :ok }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          dom_id(@document),
          partial: "documents/card",
          locals: { document: @document }
        )
      }
    end
  end

  private

  def set_document
    @document = Document.includes(blocks: []).find(params[:id])
  end

  # Normalize tag params: supports both ?tag=name (single) and ?tags[]=a&tags[]=b (multi)
  def normalize_tag_params
    if params[:tags].present?
      Array(params[:tags]).map { |t| t.to_s.strip.downcase }.reject(&:blank?)
    elsif params[:tag].present?
      [params[:tag].to_s.strip.downcase]
    else
      []
    end
  end
end
