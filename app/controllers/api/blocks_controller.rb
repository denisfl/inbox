class Api::BlocksController < Api::BaseController
  before_action :set_document
  before_action :set_block, only: [:update, :destroy]

  # POST /api/documents/:document_id/blocks
  def create
    params_for_create = block_params.to_h
    content_data = params_for_create.delete(:content)
    
    @block = @document.blocks.build(params_for_create)
    @block.content_hash = content_data if content_data.present?
    @block.save!
    
    render json: serialize_block(@block), status: :created
  end

  # PATCH /api/documents/:document_id/blocks/:id
  def update
    # Convert content parameter to use content_hash setter
    params_for_update = block_params.to_h
    if params_for_update[:content].present?
      @block.content_hash = params_for_update[:content]
      params_for_update.delete(:content)
    end

    @block.update!(params_for_update)
    render json: serialize_block(@block.reload)
  end

  # DELETE /api/documents/:document_id/blocks/:id
  def destroy
    position = @block.position
    @block.destroy!

    # Reorder remaining blocks
    @document.blocks.where('position > ?', position).order(:position).each_with_index do |block, index|
      block.update_column(:position, position + index)
    end

    head :no_content
  end

  # POST /api/documents/:document_id/blocks/reorder
  def reorder
    block_ids = params.require(:block_ids)

    # Validate all blocks belong to this document
    blocks = @document.blocks.where(id: block_ids)
    if blocks.size != block_ids.size
      return render json: { error: 'Invalid block IDs' }, status: :unprocessable_entity
    end

    # Update positions
    block_ids.each_with_index do |block_id, index|
      blocks.find(block_id).update_column(:position, index)
    end

    # Return updated blocks in order
    render json: {
      blocks: @document.blocks.ordered.map { |b| serialize_block(b) }
    }
  end


  private

  def set_document
    @document = Document.find(params[:document_id])
  end

  def set_block
    @block = @document.blocks.find(params[:id])
  end

  def block_params
    permitted = params.require(:block).permit(
      :block_type,
      :position,
      content: [
        :text,      # text, heading, quote, todo
        :level,     # heading
        :checked,   # todo
        :code,      # code
        :url,       # link
        :caption    # image, file
      ]
    )

    # Log for debugging
    Rails.logger.info "Block params: #{permitted.inspect}"
    permitted
  end

  def serialize_block(block)
    data = {
      id: block.id,
      block_type: block.block_type,
      content: block.content_hash,
      position: block.position,
      created_at: block.created_at,
      updated_at: block.updated_at
    }

    # Add attachment URLs if present
    if block.image.attached?
      data[:image_url] = url_for(block.image)
      data[:image_filename] = block.image.filename.to_s
    end

    if block.file.attached?
      data[:file_url] = url_for(block.file)
      data[:file_filename] = block.file.filename.to_s
    end

    data
  end
end
