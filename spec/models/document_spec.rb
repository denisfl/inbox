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
        expect(Document.recent).to eq([new_doc, old_doc])
      end
    end

    describe '.by_source' do
      let!(:telegram_doc) { create(:document, source: 'telegram') }
      let!(:web_doc) { create(:document, source: 'web') }
      let!(:email_doc) { create(:document, source: 'email') }

      it 'filters documents by source' do
        expect(Document.by_source('telegram')).to contain_exactly(telegram_doc)
      end
    end
  end
end
