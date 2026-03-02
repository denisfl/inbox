# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Uploads', type: :request do
  let(:token) { ENV['API_TOKEN'] || 'development_token' }
  let(:headers) { { 'Authorization' => "Token token=#{token}" } }
  let(:document) { create(:document) }
  let(:image_block) { create(:block, document: document, block_type: 'image', position: 0) }
  let(:file_block) { create(:block, document: document, block_type: 'file', position: 1) }
  let(:text_block) { create(:block, document: document, block_type: 'text', position: 2) }

  describe 'POST /api/documents/:document_id/blocks/:block_id/upload_image' do
    context 'with valid image' do
      let(:image_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

      it 'uploads image to image block' do
        post "/api/documents/#{document.id}/blocks/#{image_block.id}/upload_image",
             params: { image: image_file },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['block']).to include('id', 'url', 'filename', 'content_type', 'size')
        expect(json['block']['filename']).to eq('test_image.png')
        expect(json['block']['content_type']).to eq('image/png')

        image_block.reload
        expect(image_block.image).to be_attached
      end
    end

    context 'with invalid block type' do
      let(:image_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

      it 'returns error for non-image block' do
        post "/api/documents/#{document.id}/blocks/#{text_block.id}/upload_image",
             params: { image: image_file },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Block must be of type image')
      end
    end

    context 'without image file' do
      it 'returns error' do
        post "/api/documents/#{document.id}/blocks/#{image_block.id}/upload_image",
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('No image file provided')
      end
    end

    context 'with invalid document' do
      let(:image_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

      it 'returns not found' do
        post "/api/documents/99999/blocks/#{image_block.id}/upload_image",
             params: { image: image_file },
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/documents/:document_id/blocks/:block_id/upload_file' do
    context 'with valid file' do
      let(:pdf_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_document.pdf'), 'application/pdf') }

      it 'uploads file to file block' do
        post "/api/documents/#{document.id}/blocks/#{file_block.id}/upload_file",
             params: { file: pdf_file },
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        block_data = json['block']
        expect(block_data['id']).to eq(file_block.id)
        expect(block_data['url']).to be_present
        expect(block_data['filename']).to eq('test_document.pdf')
        expect(block_data['content_type']).to eq('application/pdf')
        expect(block_data['size']).to be_a(Integer)

        file_block.reload
        expect(file_block.file).to be_attached
      end
    end

    context 'with invalid block type' do
      let(:pdf_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/test_document.pdf'), 'application/pdf') }

      it 'returns error for non-file block' do
        post "/api/documents/#{document.id}/blocks/#{text_block.id}/upload_file",
             params: { file: pdf_file },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Block must be of type file')
      end
    end

    context 'without file' do
      it 'returns error' do
        post "/api/documents/#{document.id}/blocks/#{file_block.id}/upload_file",
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('No file provided')
      end
    end
  end
end
