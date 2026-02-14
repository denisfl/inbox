require 'rails_helper'

RSpec.describe "Api::Blocks", type: :request do
  let(:token) { ENV['API_TOKEN'] || 'development_token' }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Token token=#{token}"
    }
  end

  let(:document) { create(:document) }

  describe "POST /api/documents/:document_id/blocks" do
    let(:valid_attributes) do
      {
        block: {
          block_type: 'text',
          content: { text: 'Hello world' }.to_json
        }
      }
    end

    context "with valid parameters" do
      it "creates a new block" do
        expect {
          post "/api/documents/#{document.id}/blocks",
               params: valid_attributes.to_json,
               headers: headers
        }.to change(Block, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['block_type']).to eq('text')
        expect(json['content']['text']).to eq('Hello world')
        expect(json['position']).to eq(0)
      end

      it "auto-assigns position to next available" do
        create(:block, document: document, position: 0)
        create(:block, document: document, position: 1)

        post "/api/documents/#{document.id}/blocks",
             params: valid_attributes.to_json,
             headers: headers

        json = JSON.parse(response.body)
        expect(json['position']).to eq(2)
      end

      it "accepts explicit position" do
        valid_attributes[:block][:position] = 5

        post "/api/documents/#{document.id}/blocks",
             params: valid_attributes.to_json,
             headers: headers

        json = JSON.parse(response.body)
        expect(json['position']).to eq(5)
      end
    end

    context "with invalid parameters" do
      it "returns validation errors for invalid block_type" do
        valid_attributes[:block][:block_type] = 'invalid'

        post "/api/documents/#{document.id}/blocks",
             params: valid_attributes.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Validation failed')
      end

      it "returns not found for invalid document" do
        post "/api/documents/99999/blocks",
             params: valid_attributes.to_json,
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/documents/:document_id/blocks/:id" do
    let!(:block) { create(:block, :text, document: document, position: 0) }

    context "with valid parameters" do
      it "updates the block content" do
        patch "/api/documents/#{document.id}/blocks/#{block.id}",
              params: { block: { content: { text: 'Updated text' }.to_json } }.to_json,
              headers: headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['content']['text']).to eq('Updated text')

        block.reload
        expect(block.content_hash['text']).to eq('Updated text')
      end

      it "updates the block type" do
        patch "/api/documents/#{document.id}/blocks/#{block.id}",
              params: { block: { block_type: 'heading' } }.to_json,
              headers: headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['block_type']).to eq('heading')
      end

      it "updates the block position" do
        patch "/api/documents/#{document.id}/blocks/#{block.id}",
              params: { block: { position: 10 } }.to_json,
              headers: headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['position']).to eq(10)
      end
    end

    context "with invalid parameters" do
      it "returns validation errors" do
        patch "/api/documents/#{document.id}/blocks/#{block.id}",
              params: { block: { block_type: 'invalid' } }.to_json,
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns not found for invalid block" do
        patch "/api/documents/#{document.id}/blocks/99999",
              params: { block: { content: { text: 'test' }.to_json } }.to_json,
              headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/documents/:document_id/blocks/:id" do
    let!(:block1) { create(:block, document: document, position: 0) }
    let!(:block2) { create(:block, document: document, position: 1) }
    let!(:block3) { create(:block, document: document, position: 2) }

    it "deletes the block" do
      expect {
        delete "/api/documents/#{document.id}/blocks/#{block2.id}", headers: headers
      }.to change(Block, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Block.exists?(block2.id)).to be false
    end

    it "reorders remaining blocks after deletion" do
      delete "/api/documents/#{document.id}/blocks/#{block2.id}", headers: headers

      block1.reload
      block3.reload

      expect(block1.position).to eq(0)
      expect(block3.position).to eq(1)  # Was 2, now 1
    end

    it "returns not found for invalid block" do
      delete "/api/documents/#{document.id}/blocks/99999", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/documents/:document_id/blocks/reorder" do
    let!(:block1) { create(:block, document: document, position: 0) }
    let!(:block2) { create(:block, document: document, position: 1) }
    let!(:block3) { create(:block, document: document, position: 2) }

    context "with valid block IDs" do
      it "reorders blocks according to the provided array" do
        # Reverse the order: 3, 2, 1
        new_order = [block3.id, block2.id, block1.id]

        post "/api/documents/#{document.id}/blocks/reorder",
             params: { block_ids: new_order }.to_json,
             headers: headers

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        expect(json['blocks'].size).to eq(3)
        expect(json['blocks'][0]['id']).to eq(block3.id)
        expect(json['blocks'][1]['id']).to eq(block2.id)
        expect(json['blocks'][2]['id']).to eq(block1.id)

        # Verify positions in database
        block1.reload
        block2.reload
        block3.reload

        expect(block3.position).to eq(0)
        expect(block2.position).to eq(1)
        expect(block1.position).to eq(2)
      end

      it "handles partial reordering" do
        # Only reorder 2 blocks
        new_order = [block2.id, block1.id]

        post "/api/documents/#{document.id}/blocks/reorder",
             params: { block_ids: new_order }.to_json,
             headers: headers

        expect(response).to have_http_status(:success)
      end
    end

    context "with invalid block IDs" do
      it "returns error for non-existent block" do
        new_order = [block1.id, 99999, block3.id]

        post "/api/documents/#{document.id}/blocks/reorder",
             params: { block_ids: new_order }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid block IDs')
      end

      it "returns error for blocks from different document" do
        other_document = create(:document)
        other_block = create(:block, document: other_document)

        new_order = [block1.id, other_block.id]

        post "/api/documents/#{document.id}/blocks/reorder",
             params: { block_ids: new_order }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
