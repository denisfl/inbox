require 'rails_helper'

RSpec.describe DocumentTag, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:document) }
    it { is_expected.to belong_to(:tag) }
  end

  describe 'validations' do
    subject { build(:document_tag) }
    it { is_expected.to validate_uniqueness_of(:document_id).scoped_to(:tag_id) }
  end

  describe 'preventing duplicates' do
    let(:document) { create(:document) }
    let(:tag) { create(:tag) }

    before do
      create(:document_tag, document: document, tag: tag)
    end

    it 'prevents duplicate document-tag pairs' do
      duplicate = build(:document_tag, document: document, tag: tag)
      expect(duplicate).not_to be_valid
    end
  end
end
