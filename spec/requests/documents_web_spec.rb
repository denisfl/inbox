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

      get documents_path(tags: ["important"])

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

    it "returns 406 (no show template — documents use edit mode)" do
      get document_path(document)

      expect(response).to have_http_status(:not_acceptable)
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

    it "auto-tags the new document as web" do
      get new_document_path

      doc = Document.last
      expect(doc.tags.map(&:name)).to include("web")
    end

    it "creates an initial text block" do
      get new_document_path

      doc = Document.last
      expect(doc.blocks.count).to eq(1)
      expect(doc.blocks.first.block_type).to eq("text")
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
        post bulk_upload_documents_path, params: { files: [file] }
      }.to change(Document, :count).by(1)

      expect(response).to redirect_to(documents_path)
      doc = Document.last
      expect(doc.tags.map(&:name)).to include("web", "file")
    end

    it "handles image uploads with image block" do
      file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_image.png"),
        "image/png"
      )

      expect {
        post bulk_upload_documents_path, params: { files: [file] }
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
        post bulk_upload_documents_path, params: { files: [file1, file2] }
      }.to change(Document, :count).by(2)
    end

    it "auto-tags audio files" do
      audio_file = fixture_file_upload(
        Rails.root.join("spec", "fixtures", "files", "test_upload.txt"),
        "audio/mpeg"
      )

      post bulk_upload_documents_path, params: { files: [audio_file] }

      doc = Document.last
      expect(doc.tags.map(&:name)).to include("audio")
    end
  end
end
