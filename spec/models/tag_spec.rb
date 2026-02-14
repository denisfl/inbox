require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'associations' do
    it { is_expected.to have_many(:document_tags).dependent(:destroy) }
    it { is_expected.to have_many(:documents).through(:document_tags) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    
    context 'name uniqueness' do
      subject { create(:tag) }
      it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
    end
  end

  describe 'callbacks' do
    context 'before_validation :normalize_name' do
      it 'converts name to lowercase' do
        tag = create(:tag, name: 'UPPERCASE')
        expect(tag.name).to eq('uppercase')
      end

      it 'strips whitespace' do
        tag = create(:tag, name: '  spaced  ')
        expect(tag.name).to eq('spaced')
      end
    end
  end

  describe 'scopes' do
    describe '.alphabetical' do
      let!(:tag_z) { create(:tag, name: 'zebra') }
      let!(:tag_a) { create(:tag, name: 'apple') }
      let!(:tag_m) { create(:tag, name: 'mango') }

      it 'returns tags ordered alphabetically' do
        expect(Tag.alphabetical).to eq([tag_a, tag_m, tag_z])
      end
    end

    describe '.popular' do
      let!(:popular_tag) { create(:tag) }
      let!(:unpopular_tag) { create(:tag) }
      let(:doc1) { create(:document) }
      let(:doc2) { create(:document) }
      let(:doc3) { create(:document) }

      before do
        create(:document_tag, document: doc1, tag: popular_tag)
        create(:document_tag, document: doc2, tag: popular_tag)
        create(:document_tag, document: doc3, tag: popular_tag)
        create(:document_tag, document: doc1, tag: unpopular_tag)
      end

      it 'returns tags ordered by document count' do
        expect(Tag.popular.first).to eq(popular_tag)
      end
    end
  end
end
