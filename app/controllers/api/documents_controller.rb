class Api::DocumentsController < Api::BaseController
  include ApplicationHelper

  before_action :set_document, only: [ :show, :update, :destroy, :upload, :preview, :transcribe ]

  # GET /api/documents
  def index
    @documents = Document.includes(:tags, :blocks)
                         .recent
                         .page(params[:page])
                         .per(params[:per_page] || 20)

    render json: {
      documents: @documents.map { |doc| document_summary(doc) },
      meta: pagination_meta(@documents)
    }
  end

  # GET /api/documents/search?q=query
  def search
    query = params[:q]
    page = params[:page]&.to_i || 1
    per_page = params[:per_page]&.to_i || 20

    if query.blank?
      return render json: { error: "Query parameter is required" }, status: :bad_request
    end

    start_time = Time.now
    @results = Document.search(query, page: page, per_page: per_page)
    total = Document.search_count(query)
    search_time = ((Time.now - start_time) * 1000).round(2)

    render json: {
      results: @results.map { |doc| search_result(doc) },
      meta: {
        query: query,
        total: total,
        page: page,
        per_page: per_page,
        total_pages: (total.to_f / per_page).ceil,
        search_time_ms: search_time
      }
    }
  end

  # GET /api/documents/:id
  def show
    render json: document_detail(@document)
  end

  # POST /api/documents
  def create
    @document = Document.new(document_params)

    if @document.save
      render json: document_detail(@document), status: :created
    else
      render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/documents/:id
  def update
    if @document.update(document_params)
      render json: document_detail(@document)
    else
      render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/documents/:id
  def destroy
    @document.destroy
    head :no_content
  end

  # GET /api/documents/:id/preview
  # Returns rendered HTML for the whole document:
  #   - native <audio> players for each audio file block
  #   - rich text body from Action Text
  def preview
    audio_mime_re = /\Aaudio\//
    audio_ext_re  = /\.(ogg|mp3|m4a|wav|opus|aac|flac|webm)\z/i
    audio_html    = ""

    @document.blocks.where(block_type: "file").find_each do |b|
      next unless b.file.attached?
      next unless b.file.content_type.to_s.match?(audio_mime_re) ||
                  b.file.filename.to_s.match?(audio_ext_re)

      audio_url = url_for(b.file)
      filename  = ERB::Util.html_escape(b.file.filename.to_s)
      safe_url  = ERB::Util.html_escape(audio_url)
      audio_html += <<~HTML
        <div class="audio-block">
          <audio controls preload="metadata" src="#{safe_url}" style="width:100%">
            Your browser does not support audio playback.
          </audio>
          <div class="audio-block-filename">🎙 #{filename}</div>
        </div>
      HTML
    end

    body_html = @document.body.to_s

    render json: { html: audio_html + body_html }
  end

  # POST /api/documents/:id/upload
  # Attaches a file or image to the document via a new Block + Active Storage.
  # Returns { url, filename, is_image, block_id, byte_size } on success.
  def upload
    file = params[:file]
    return render json: { error: "No file provided" }, status: :bad_request if file.blank?

    is_image = file.content_type.to_s.start_with?("image/")
    is_audio = file.content_type.to_s.start_with?("audio/")

    if is_image
      block = @document.blocks.create!(
        block_type: "image",
        content: {}.to_json
      )
      block.image.attach(file)
      attachment = block.image
    else
      block = @document.blocks.create!(
        block_type: "file",
        content: { filename: file.original_filename }.to_json
      )
      block.file.attach(file)
      attachment = block.file
    end

    render json: {
      url: url_for(attachment),
      filename: attachment.filename.to_s,
      is_image: is_image,
      is_audio: is_audio,
      block_id: block.id,
      byte_size: attachment.byte_size
    }
  end

  # POST /api/documents/:id/transcribe
  # Enqueues transcription for all audio blocks in the document.
  # Supports re-transcription — existing text block will be replaced.
  def transcribe
    audio_mime_prefix = "audio/"
    audio_extensions  = %w[.ogg .mp3 .m4a .wav .opus .aac .flac .webm]

    audio_blocks = @document.blocks.where(block_type: "file").select do |b|
      b.file.attached? &&
        (b.file.content_type.to_s.start_with?(audio_mime_prefix) ||
         audio_extensions.any? { |ext| b.file.filename.to_s.end_with?(ext) })
    end

    if audio_blocks.empty?
      return render json: { error: "No audio files found in this document" }, status: :unprocessable_entity
    end

    audio_blocks.each do |block|
      TranscribeAudioJob.perform_later(@document.id, block.file.blob.key)
    end

    render json: { message: "Transcription started for #{audio_blocks.size} audio file(s)", audio_count: audio_blocks.size }
  end

  private

  def set_document
    @document = Document.includes(:tags, :blocks).find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :slug, tag_ids: [])
  end

  def document_summary(doc)
    {
      id: doc.id,
      title: doc.title,
      slug: doc.slug,
      blocks_count: doc.blocks.size,
      tags: doc.tags.map(&:name),
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end

  def document_detail(doc)
    {
      id: doc.id,
      title: doc.title,
      slug: doc.slug,
      blocks: doc.blocks.ordered.map { |block| serialize_block(block) },
      tags: doc.tags.map { |tag| { id: tag.id, name: tag.name } },
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end

  def serialize_block(block)
    {
      id: block.id,
      block_type: block.block_type,
      position: block.position,
      content: block.content_hash,
      created_at: block.created_at,
      updated_at: block.updated_at
    }
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end

  def search_result(doc)
    {
      id: doc.id,
      title: doc.title,
      slug: doc.slug,
      title_snippet: doc.respond_to?(:title_snippet) ? doc.title_snippet : doc.title,
      content_snippet: doc.respond_to?(:content_snippet) ? doc.content_snippet : "",
      rank: doc.respond_to?(:rank) ? doc.rank : 0,
      blocks_count: doc.blocks.count,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
