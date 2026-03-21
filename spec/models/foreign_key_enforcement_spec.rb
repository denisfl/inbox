require "rails_helper"

RSpec.describe "Foreign key enforcement", type: :model do
  # Suppress wiki-link extraction subscriber to avoid interference
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

  describe "FK constraint enforcement" do
    it "rejects document_link with non-existent source_document_id at DB level" do
      target = create(:document)
      link = DocumentLink.new(source_document_id: 999_999, target_document_id: target.id)
      expect {
        link.save(validate: false)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "rejects document_link with non-existent target_document_id at DB level" do
      source = create(:document)
      link = DocumentLink.new(source_document_id: source.id, target_document_id: 999_999)
      expect {
        link.save(validate: false)
      }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe "cascade deletion" do
    it "deletes document_links when source document is destroyed" do
      source = create(:document)
      target = create(:document)
      create(:document_link, source_document: source, target_document: target)

      expect { source.destroy! }.to change(DocumentLink, :count).by(-1)
    end

    it "deletes document_tags when document is destroyed" do
      doc = create(:document)
      tag = create(:tag)
      doc.tags << tag

      expect { doc.destroy! }.to change(DocumentTag, :count).by(-1)
    end

    it "deletes blocks when document is destroyed" do
      doc = create(:document)
      create(:block, document: doc)

      expect { doc.destroy! }.to change(Block, :count).by(-1)
    end

    it "deletes task_tags when task is destroyed" do
      task = create(:task)
      tag = create(:tag)
      task.tags << tag

      expect { task.destroy! }.to change(TaskTag, :count).by(-1)
    end

    it "deletes calendar_event_tags when calendar event is destroyed" do
      event = create(:calendar_event)
      tag = create(:tag)
      event.tags << tag

      expect { event.destroy! }.to change(CalendarEventTag, :count).by(-1)
    end

    it "deletes document_tags and task_tags when tag is destroyed" do
      tag = create(:tag)
      doc = create(:document)
      task = create(:task)
      doc.tags << tag
      task.tags << tag

      expect { tag.destroy! }.to change(DocumentTag, :count).by(-1)
        .and change(TaskTag, :count).by(-1)
    end
  end
end
