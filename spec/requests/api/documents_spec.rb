require 'rails_helper'

RSpec.describe "Api::Documents", type: :request do
  let(:token) { ENV['API_TOKEN'] || 'development_token' }
  let(:headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Token token=#{token}"
    }
  end
  
  describe "GET /api/documents" do
    let!(:documents) { create_list(:document, 3) }

    it "returns paginated list of documents" do
      get "/api/documents", headers: headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json['documents']).to be_an(Array)
      expect(json['documents'].size).to eq(3)
      expect(json['meta']).to include('current_page', 'total_pages', 'total_count', 'per_page')
    end

    it "returns documents with summary data" do
      get "/api/documents", headers: headers
      
      json = JSON.parse(response.body)
      document = json['documents'].first
      
      expect(document).to include('id', 'title', 'slug', 'source', 'blocks_count', 'tags', 'created_at', 'updated_at')
    end

    it "supports pagination parameters" do
      create_list(:document, 25)
      
      get "/api/documents?page=2&per_page=10", headers: headers
      
      json = JSON.parse(response.body)
      expect(json['meta']['current_page']).to eq(2)
      expect(json['meta']['per_page']).to eq(10)
    end
  end

  describe "GET /api/documents/:id" do
    let(:document) { create(:document) }
    let!(:blocks) { create_list(:block, 3, :text, document: document) }
    let!(:tags) { create_list(:tag, 2).each { |tag| document.tags << tag } }

    context "when document exists" do
      it "returns document with full details" do
        get "/api/documents/#{document.id}", headers: headers
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        
        expect(json['id']).to eq(document.id)
        expect(json['blocks']).to be_an(Array)
        expect(json['blocks'].size).to eq(3)
        expect(json['tags']).to be_an(Array)
        expect(json['tags'].size).to eq(2)
      end

      it "includes block details" do
        get "/api/documents/#{document.id}", headers: headers
        
        json = JSON.parse(response.body)
        block = json['blocks'].first
        
        expect(block).to include('id', 'block_type', 'position', 'content', 'created_at', 'updated_at')
      end
    end

    context "when document does not exist" do
      it "returns not found" do
        get "/api/documents/999999", headers: headers
        
        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Record not found')
      end
    end
  end

  describe "POST /api/documents" do
    let(:valid_attributes) do
      { document: { title: 'New Document', source: 'web' } }
    end

    let(:invalid_attributes) do
      { document: { title: '', source: 'web' } }
    end

    context "with valid parameters" do
      it "creates a new document" do
        expect {
          post "/api/documents", params: valid_attributes.to_json, headers: headers
        }.to change(Document, :count).by(1)
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('New Document')
        expect(json['slug']).to eq('new-document')
      end
    end

    context "with invalid parameters" do
      it "returns validation errors" do
        post "/api/documents", params: invalid_attributes.to_json, headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_an(Array)
      end
    end
  end

  describe "PATCH /api/documents/:id" do
    let(:document) { create(:document, title: 'Old Title') }
    let(:new_attributes) { { document: { title: 'Updated Title' } } }

    context "with valid parameters" do
      it "updates the document" do
        patch "/api/documents/#{document.id}", params: new_attributes.to_json, headers: headers
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['title']).to eq('Updated Title')
        
        document.reload
        expect(document.title).to eq('Updated Title')
      end
    end

    context "with invalid parameters" do
      it "returns validation errors" do
        patch "/api/documents/#{document.id}", 
              params: { document: { title: '' } }.to_json, 
              headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /api/documents/:id" do
    let!(:document) { create(:document) }

    it "destroys the document" do
      expect {
        delete "/api/documents/#{document.id}", headers: headers
      }.to change(Document, :count).by(-1)
      
      expect(response).to have_http_status(:no_content)
    end
  end
end
