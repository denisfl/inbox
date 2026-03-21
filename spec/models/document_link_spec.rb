require 'rails_helper'

RSpec.describe DocumentLink, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:source_document).class_name('Document') }
    it { is_expected.to belong_to(:target_document).class_name('Document') }
  end

  describe 'validations' do
    # Suppress event-driven wiki-link extraction so DocumentLinkExtractor
    # doesn't delete_all outgoing_links during shoulda-matchers probing
    before do
      @subscriptions = []
      %w[document.created document.updated].each do |event|
        ActiveSupport::Notifications.notifier.listeners_for(event).each do |sub|
          @subscriptions << [ event, sub ]
          ActiveSupport::Notifications.unsubscribe(sub)
        end
      end
    end

    after do
      @subscriptions.each do |event_name, _sub|
        WikiLinkExtractionSubscriber.subscribe(event_name)
      end
    end

    subject { build(:document_link) }
    it { is_expected.to validate_uniqueness_of(:source_document_id).scoped_to(:target_document_id) }
  end

  describe 'preventing duplicates' do
    let(:source) { create(:document) }
    let(:target) { create(:document) }

    before do
      create(:document_link, source_document: source, target_document: target)
    end

    it 'prevents duplicate source-target pairs' do
      duplicate = build(:document_link, source_document: source, target_document: target)
      expect(duplicate).not_to be_valid
    end

    it 'allows reverse direction' do
      reverse = build(:document_link, source_document: target, target_document: source)
      expect(reverse).to be_valid
    end
  end

  describe 'cascading destroy' do
    let!(:source) { create(:document) }
    let!(:target) { create(:document) }
    let!(:link) { create(:document_link, source_document: source, target_document: target) }

    it 'destroys links when source document is destroyed' do
      expect { source.destroy }.to change(DocumentLink, :count).by(-1)
    end

    it 'destroys links when target document is destroyed' do
      expect { target.destroy }.to change(DocumentLink, :count).by(-1)
    end
  end
end
