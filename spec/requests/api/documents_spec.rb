require 'rails_helper'

RSpec.describe "Api::Documents", type: :request do
  let(:token) { ENV['API_TOKEN'].presence || 'development_token' }
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
      doc = create(:document)
      tag = create(:tag, name: "summary_test")
      doc.tags << tag
      doc.blocks.create!(block_type: "text", position: 0, content: { text: "block" }.to_json)

      get "/api/documents", headers: headers

      json = JSON.parse(response.body)
      document = json['documents'].find { |d| d['id'] == doc.id }

      expect(document).to include('id', 'title', 'slug', 'blocks_count', 'tags', 'created_at', 'updated_at')
      expect(document['blocks_count']).to eq(1)
      expect(document['tags']).to include("summary_test")
      expect(document['slug']).to be_present
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

  describe "GET /api/documents/search" do
    it "returns 400 when query is blank" do
      get "/api/documents/search", headers: headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Query parameter is required")
    end

    it "returns search results for a valid query" do
      doc = create(:document, title: "Unique searchable title xyz")
      block = doc.blocks.create!(block_type: "text", position: 0)
      block.content_hash = { text: "body text" }
      block.save!

      # Stub FTS5 since the virtual table doesn't exist in test
      allow(Document).to receive(:search).and_return([ doc ])
      allow(Document).to receive(:search_count).and_return(1)

      get "/api/documents/search?q=searchable", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to include("results", "meta")
      expect(json["meta"]).to include("query", "total", "page", "per_page", "total_pages", "search_time_ms")
    end

    it "returns search results with snippets from FTS5" do
      doc = create(:document, title: "FTS search result")
      doc.blocks.create!(block_type: "text", position: 0, content: { text: "body" }.to_json)

      # Stub FTS5 methods to return actual results with snippets
      fts_doc = doc
      fts_doc.define_singleton_method(:title_snippet) { "<mark>FTS</mark> search result" }
      fts_doc.define_singleton_method(:content_snippet) { "matched <mark>body</mark>" }
      fts_doc.define_singleton_method(:rank) { -2.5 }

      allow(Document).to receive(:search).and_return([ fts_doc ])
      allow(Document).to receive(:search_count).and_return(1)

      get "/api/documents/search?q=FTS", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["results"].size).to eq(1)
      result = json["results"].first
      expect(result["title_snippet"]).to include("FTS")
      expect(result["content_snippet"]).to include("body")
      expect(result["rank"]).to eq(-2.5)
      expect(json["meta"]["total"]).to eq(1)
      expect(json["meta"]["total_pages"]).to eq(1)
    end
  end

  describe "GET /api/documents/:id/preview" do
    let(:document) { create(:document) }

    it "returns rendered HTML for document body" do
      document.update!(body: "Hello <strong>world</strong>")

      get "/api/documents/#{document.id}/preview", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["html"]).to include("Hello")
    end

    it "returns empty html when document has no body" do
      get "/api/documents/#{document.id}/preview", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["html"]).to eq("")
    end

    it "renders audio player for audio file blocks" do
      block = document.blocks.create!(block_type: "file", position: 0)
      block.content_hash = { filename: "voice.ogg" }
      block.save!
      block.file.attach(
        io: StringIO.new("fake audio"),
        filename: "voice.ogg",
        content_type: "audio/ogg"
      )

      get "/api/documents/#{document.id}/preview", headers: headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["html"]).to include("<audio")
      expect(json["html"]).to include("voice.ogg")
    end
  end

  describe "POST /api/documents/:id/upload" do
    let(:document) { create(:document) }

    it "returns error when no file provided" do
      post "/api/documents/#{document.id}/upload", headers: headers.except("Content-Type")

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("No file provided")
    end

    it "uploads an image file and creates an image block" do
      image = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_image.png"),
        "image/png"
      )

      post "/api/documents/#{document.id}/upload",
           params: { file: image },
           headers: { "Authorization" => "Token token=#{token}" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["is_image"]).to be true
      expect(json["filename"]).to eq("test_image.png")
      expect(json).to include("url", "block_id", "byte_size")
    end

    it "uploads a non-image file and creates a file block" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_upload.txt"),
        "text/plain"
      )

      post "/api/documents/#{document.id}/upload",
           params: { file: file },
           headers: { "Authorization" => "Token token=#{token}" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["is_image"]).to be false
      expect(json["is_audio"]).to be false
      expect(json["filename"]).to eq("test_upload.txt")
    end

    it "uploads an audio file and creates file block" do
      audio = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_audio.webm"),
        "audio/webm"
      )

      expect {
        post "/api/documents/#{document.id}/upload",
             params: { file: audio },
             headers: { "Authorization" => "Token token=#{token}" }
      }.not_to have_enqueued_job(TranscribeAudioJob)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["is_audio"]).to be true
      expect(json["is_image"]).to be false
    end

    it "does not enqueue TranscribeAudioJob for image uploads" do
      image = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/test_image.png"),
        "image/png"
      )

      expect {
        post "/api/documents/#{document.id}/upload",
             params: { file: image },
             headers: { "Authorization" => "Token token=#{token}" }
      }.not_to have_enqueued_job(TranscribeAudioJob)
    end
  end
end
