require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:blocks).dependent(:destroy) }
    it { is_expected.to have_many(:document_tags).dependent(:destroy) }
    it { is_expected.to have_many(:tags).through(:document_tags) }
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
        expect(Document.tagged_with(["alpha"])).to contain_exactly(doc_ab, doc_a)
      end

      it 'returns documents matching all tags (AND)' do
        expect(Document.tagged_with(["alpha", "beta"])).to contain_exactly(doc_ab)
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
        [fts_row.values]
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
