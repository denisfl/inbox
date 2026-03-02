# frozen_string_literal: true

module Api
  class UploadsController < Api::BaseController
    before_action :set_document
    before_action :set_block

    # POST /api/documents/:document_id/blocks/:block_id/upload_image
    def upload_image
      if @block.block_type != "image"
        return render json: { error: "Block must be of type image" }, status: :unprocessable_entity
      end

      if params[:image].blank?
        return render json: { error: "No image file provided" }, status: :unprocessable_entity
      end

      @block.image.attach(params[:image])

      if @block.save
        render json: {
          block: {
            id: @block.id,
            url: url_for(@block.image),
            filename: @block.image.filename.to_s,
            content_type: @block.image.content_type,
            size: @block.image.byte_size
          }
        }, status: :ok
      else
        render json: { errors: @block.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # POST /api/documents/:document_id/blocks/:block_id/upload_file
    def upload_file
      if @block.block_type != "file"
        return render json: { error: "Block must be of type file" }, status: :unprocessable_entity
      end

      if params[:file].blank?
        return render json: { error: "No file provided" }, status: :unprocessable_entity
      end

      @block.file.attach(params[:file])

      if @block.save
        render json: {
          block: {
            id: @block.id,
            url: url_for(@block.file),
            filename: @block.file.filename.to_s,
            content_type: @block.file.content_type,
            size: @block.file.byte_size
          }
        }, status: :ok
      else
        render json: { errors: @block.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_document
      @document = Document.find(params[:document_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Document not found" }, status: :not_found
    end

    def set_block
      @block = @document.blocks.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "Block not found" }, status: :not_found
    end
  end
end
