# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Documents (web)", type: :request do
  describe "GET /documents" do
    it "returns success" do
      get documents_path

      expect(response).to have_http_status(:ok)
    end

    it "lists documents" do
      create(:document, title: "My note")

      get documents_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My note")
    end

    it "searches by query" do
      doc = create(:document, title: "Searchable note")

      get documents_path(q: "Searchable")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Searchable note")
    end

    it "filters by tags" do
      doc = create(:document, title: "Tagged doc")
      tag = create(:tag, name: "important")
      create(:document_tag, document: doc, tag: tag)

      get documents_path(tags: [ "important" ])

      expect(response).to have_http_status(:ok)
    end

    it "sorts by created_asc" do
      get documents_path(sort: "created_asc")

      expect(response).to have_http_status(:ok)
    end

    it "sorts by created_desc" do
      get documents_path(sort: "created_desc")

      expect(response).to have_http_status(:ok)
    end

    it "sorts by title_asc" do
      get documents_path(sort: "title_asc")

      expect(response).to have_http_status(:ok)
    end

    it "sorts by title_desc" do
      get documents_path(sort: "title_desc")

      expect(response).to have_http_status(:ok)
    end

    it "filters by voice type" do
      get documents_path(type: "voice")

      expect(response).to have_http_status(:ok)
    end

    it "filters by photo type" do
      get documents_path(type: "photo")

      expect(response).to have_http_status(:ok)
    end

    it "paginates results" do
      25.times { create(:document) }

      get documents_path

      expect(response).to have_http_status(:ok)
    end

    it "supports single tag param" do
      doc = create(:document, title: "Single param doc")
      tag = create(:tag, name: "solo")
      create(:document_tag, document: doc, tag: tag)

      get documents_path(tag: "solo")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /documents/:id" do
    let(:document) { create(:document, :with_initial_block) }

    it "returns success (show template)" do
      get document_path(document)

      expect(response).to have_http_status(:ok)
    end

    context "backlinks" do
      it "displays Connected Documents section when backlinks exist" do
        source = create(:document, title: "Linking Doc")
        target = create(:document, title: "Target Doc")
        create(:document_link, source_document: source, target_document: target)

        get document_path(target)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Connected Documents")
        expect(response.body).to include("Linking Doc")
      end

      it "hides Connected Documents section when no backlinks" do
        doc = create(:document, title: "Lonely Doc")

        get document_path(doc)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Connected Documents")
      end
    end
  end

  describe "GET /documents/:id/edit" do
    let(:document) { create(:document, :with_initial_block) }

    it "returns success" do
      get edit_document_path(document)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /documents/new" do
    it "creates a new document and redirects to edit" do
      expect {
        get new_document_path
      }.to change(Document, :count).by(1)

      expect(response).to redirect_to(edit_document_path(Document.last))
    end

    it "does not auto-tag the new document as web" do
      get new_document_path

      doc = Document.last
      expect(doc.tags.map(&:name)).not_to include("web")
    end

    it "does not create any blocks (uses Action Text body)" do
      get new_document_path

      doc = Document.last
      expect(doc.blocks.count).to eq(0)
    end
  end

  describe "DELETE /documents/:id" do
    let!(:document) { create(:document) }

    it "deletes the document" do
      expect {
        delete document_path(document)
      }.to change(Document, :count).by(-1)

      expect(response).to redirect_to(documents_path)
    end

    it "cascades deletion to blocks and tags" do
      block = create(:block, document: document)
      tag = create(:tag)
      create(:document_tag, document: document, tag: tag)

      expect {
        delete document_path(document)
      }.to change(Block, :count).by(-1)
        .and change(DocumentTag, :count).by(-1)
    end
  end

  describe "PATCH /documents/:id/toggle_pinned" do
    let(:document) { create(:document, pinned: false) }

    it "toggles the pinned status" do
      patch toggle_pinned_document_path(document)

      expect(document.reload.pinned).to be true
    end

    it "redirects back for HTML" do
      patch toggle_pinned_document_path(document)

      expect(response).to have_http_status(:redirect)
    end

    it "returns JSON for JSON requests" do
      patch toggle_pinned_document_path(document), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["pinned"]).to be true
    end

    it "returns turbo_stream for turbo requests" do
      patch toggle_pinned_document_path(document), headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end
  end

  describe "POST /documents/bulk_upload" do
    it "creates documents from uploaded files" do
      file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "text/plain"
      )

      expect {
        post bulk_upload_documents_path, params: { files: [ file ] }
      }.to change(Document, :count).by(1)

      expect(response).to redirect_to(documents_path)
      doc = Document.last
      expect(doc.tags.map(&:name)).to include("file")
      expect(doc.tags.map(&:name)).not_to include("web")
    end

    it "handles image uploads with image block" do
      file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_image.png"),
        "image/png"
      )

      expect {
        post bulk_upload_documents_path, params: { files: [ file ] }
      }.to change(Document, :count).by(1)

      doc = Document.last
      expect(doc.blocks.find_by(block_type: "image")).to be_present
    end

    it "redirects with alert when no files selected" do
      post bulk_upload_documents_path, params: { files: nil }

      expect(response).to redirect_to(documents_path)
    end

    it "handles multiple files" do
      file1 = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "text/plain"
      )
      file2 = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "text/plain"
      )

      expect {
        post bulk_upload_documents_path, params: { files: [ file1, file2 ] }
      }.to change(Document, :count).by(2)
    end

    it "auto-tags audio files" do
      audio_file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "audio/mpeg"
      )

      post bulk_upload_documents_path, params: { files: [ audio_file ] }

      doc = Document.last
      expect(doc.tags.map(&:name)).to include("audio")
    end
  end

  describe "GET /documents/search.json" do
    it "returns matching documents" do
      create(:document, title: "Meeting Notes")
      create(:document, title: "Team Meeting")
      create(:document, title: "Grocery List")

      get search_documents_path(q: "meet", format: :json)

      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)
      expect(results.length).to eq(2)
      titles = results.map { |r| r["title"] }
      expect(titles).to contain_exactly("Meeting Notes", "Team Meeting")
    end

    it "returns empty array for empty query" do
      create(:document, title: "Something")

      get search_documents_path(q: "", format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "returns empty array when no query parameter" do
      get search_documents_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "limits results to 10" do
      12.times { |i| create(:document, title: "Note #{i}") }

      get search_documents_path(q: "Note", format: :json)

      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)
      expect(results.length).to eq(10)
    end

    it "returns id and title for each result" do
      doc = create(:document, title: "My Document")

      get search_documents_path(q: "My", format: :json)

      results = JSON.parse(response.body)
      expect(results.first).to include("id" => doc.id, "title" => "My Document")
    end

    it "is case-insensitive" do
      create(:document, title: "Important Note")

      get search_documents_path(q: "important", format: :json)

      results = JSON.parse(response.body)
      expect(results.length).to eq(1)
    end
  end
end
