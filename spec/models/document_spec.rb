require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:blocks).dependent(:destroy) }
    it { is_expected.to have_many(:document_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:document_tags) }
    it { is_expected.to have_many(:outgoing_links).class_name('DocumentLink').dependent(:destroy) }
    it { is_expected.to have_many(:incoming_links).class_name('DocumentLink').dependent(:destroy) }
    it { is_expected.to have_many(:linked_documents).through(:outgoing_links).source(:target_document) }
    it { is_expected.to have_many(:linking_documents).through(:incoming_links).source(:source_document) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }

    context 'slug uniqueness' do
      subject { build(:document, slug: 'test-slug') }
      it { is_expected.to validate_uniqueness_of(:slug) }
    end
  end

  describe 'callbacks' do
    context 'when title is present and slug is blank' do
      let(:document) { build(:document, title: 'Test Document', slug: nil) }

      it 'generates slug from title' do
        document.save
        expect(document.slug).to eq('test-document')
      end
    end

    context 'when slug is already set' do
      let(:document) { build(:document, title: 'Test Document', slug: 'custom-slug') }

      it 'does not override existing slug' do
        document.save
        expect(document.slug).to eq('custom-slug')
      end
    end
  end

  describe 'scopes' do
    describe '.recent' do
      let!(:old_doc) { create(:document, created_at: 2.days.ago) }
      let!(:new_doc) { create(:document, created_at: 1.day.ago) }

      it 'returns documents ordered by created_at desc' do
        expect(Document.recent).to eq([ new_doc, old_doc ])
      end
    end

    describe '.todos' do
      let!(:todo_doc) { create(:document, document_type: "todo") }
      let!(:note_doc) { create(:document, document_type: "note") }

      it 'returns only todo documents' do
        expect(Document.todos).to contain_exactly(todo_doc)
      end
    end

    describe '.notes' do
      let!(:note_doc) { create(:document, document_type: "note") }
      let!(:todo_doc) { create(:document, document_type: "todo") }

      it 'returns only note documents' do
        expect(Document.notes).to contain_exactly(note_doc)
      end
    end

    describe '.pinned' do
      let!(:pinned_doc) { create(:document, pinned: true) }
      let!(:unpinned_doc) { create(:document, pinned: false) }

      it 'returns only pinned documents' do
        expect(Document.pinned).to contain_exactly(pinned_doc)
      end
    end

    describe '.not_pinned' do
      let!(:pinned_doc) { create(:document, pinned: true) }
      let!(:unpinned_doc) { create(:document, pinned: false) }

      it 'returns only unpinned documents' do
        expect(Document.not_pinned).to contain_exactly(unpinned_doc)
      end
    end

    describe '.tagged_with' do
      let!(:tag_a) { create(:tag, name: "alpha") }
      let!(:tag_b) { create(:tag, name: "beta") }
      let!(:doc_ab) { create(:document) }
      let!(:doc_a)  { create(:document) }

      before do
        doc_ab.tags << tag_a
        doc_ab.tags << tag_b
        doc_a.tags << tag_a
      end

      it 'returns documents matching a single tag' do
        expect(Document.tagged_with([ "alpha" ])).to contain_exactly(doc_ab, doc_a)
      end

      it 'returns documents matching all tags (AND)' do
        expect(Document.tagged_with([ "alpha", "beta" ])).to contain_exactly(doc_ab)
      end

      it 'returns all documents when tags are blank' do
        expect(Document.tagged_with([])).to contain_exactly(doc_ab, doc_a)
      end
    end
  end

  describe '#toggle_pinned!' do
    let(:document) { create(:document, pinned: false) }

    it 'toggles pinned from false to true' do
      document.toggle_pinned!
      expect(document.reload.pinned).to be true
    end

    it 'toggles pinned from true to false' do
      document.update!(pinned: true)
      document.toggle_pinned!
      expect(document.reload.pinned).to be false
    end
  end

  describe 'wiki-link associations' do
    let!(:doc_a) { create(:document, title: "Document A") }
    let!(:doc_b) { create(:document, title: "Document B") }
    let!(:doc_c) { create(:document, title: "Document C") }

    before do
      create(:document_link, source_document: doc_a, target_document: doc_b)
      create(:document_link, source_document: doc_a, target_document: doc_c)
      create(:document_link, source_document: doc_c, target_document: doc_a)
    end

    it 'returns linked documents via outgoing links' do
      expect(doc_a.linked_documents).to contain_exactly(doc_b, doc_c)
    end

    it 'returns linking documents via incoming links (backlinks)' do
      expect(doc_a.linking_documents).to contain_exactly(doc_c)
    end

    it 'returns empty for documents with no links' do
      expect(doc_b.linked_documents).to be_empty
    end

    it 'returns backlinks for document referenced by others' do
      expect(doc_b.linking_documents).to contain_exactly(doc_a)
    end
  end

  describe 'after_save wiki-link extraction' do
    let!(:target) { create(:document, title: "Target Note") }

    it 'extracts wiki-links on save' do
      source = create(:document, title: "Source")
      source.update!(body: "See [[Target Note]]")

      expect(source.reload.linked_documents).to contain_exactly(target)
    end

    it 'removes links when wiki-link text is removed' do
      source = create(:document, title: "Source")
      source.update!(body: "See [[Target Note]]")
      expect(source.reload.linked_documents).to contain_exactly(target)

      source.update!(body: "No links anymore")
      expect(source.reload.linked_documents).to be_empty
    end
  end

  describe '.search' do
    it 'returns empty relation for blank query' do
      expect(Document.search("")).to be_empty
    end

    it 'returns documents with snippet methods when FTS5 returns results' do
      doc = create(:document, title: "Searchable Document")

      # Stub FTS5 SQL response since FTS5 virtual table may not exist in test
      fts_row = {
        "id" => doc.id,
        "title_snippet" => "<mark>Searchable</mark> Document",
        "content_snippet" => "Some <mark>searchable</mark> content",
        "rank" => -1.5
      }
      fts_result = ActiveRecord::Result.new(
        fts_row.keys,
        [ fts_row.values ]
      )
      allow(Document.connection).to receive(:select_all).and_return(fts_result)

      results = Document.search("Searchable")

      expect(results.size).to eq(1)
      expect(results.first.id).to eq(doc.id)
      expect(results.first.title_snippet).to eq("<mark>Searchable</mark> Document")
      expect(results.first.content_snippet).to eq("Some <mark>searchable</mark> content")
      expect(results.first.rank).to eq(-1.5)
    end
  end

  describe '.search_count' do
    it 'returns 0 for blank query' do
      expect(Document.search_count("")).to eq(0)
    end

    it 'returns count from FTS5 query' do
      # Stub FTS5 count query
      allow(Document.connection).to receive(:select_value).and_return(5)

      result = Document.search_count("test query")

      expect(result).to eq(5)
    end
  end

  describe 'slug collision' do
    it 'generates unique slug with timestamp when duplicate exists' do
      create(:document, title: "Test Document", slug: "test-document")
      doc2 = create(:document, title: "Test Document", slug: nil)
      expect(doc2.slug).to start_with("test-document-")
      expect(doc2.slug).not_to eq("test-document")
    end
  end
end
