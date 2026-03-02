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
end
