class Api::DocumentsController < Api::BaseController
  before_action :set_document, only: [:show, :update, :destroy]

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
      return render json: { error: 'Query parameter is required' }, status: :bad_request
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

  private

  def set_document
    @document = Document.includes(:tags, :blocks).find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :slug, :source, :body, tag_ids: [])
  end

  def document_summary(doc)
    {
      id: doc.id,
      title: doc.title,
      slug: doc.slug,
      source: doc.source,
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
      source: doc.source,
      body: doc.body,
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
      source: doc.source,
      title_snippet: doc.respond_to?(:title_snippet) ? doc.title_snippet : doc.title,
      content_snippet: doc.respond_to?(:content_snippet) ? doc.content_snippet : '',
      rank: doc.respond_to?(:rank) ? doc.rank : 0,
      blocks_count: doc.blocks.count,
      created_at: doc.created_at,
      updated_at: doc.updated_at
    }
  end
end
