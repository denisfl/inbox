require "rails_helper"

RSpec.describe DocumentLinkExtractor do
  # Suppress event-driven extraction so we control when extraction runs
  before do
    @subscriptions = []
    ActiveSupport::Notifications.notifier.listeners_for("document.created").each do |sub|
      @subscriptions << [ "document.created", sub ]
      ActiveSupport::Notifications.unsubscribe(sub)
    end
    ActiveSupport::Notifications.notifier.listeners_for("document.updated").each do |sub|
      @subscriptions << [ "document.updated", sub ]
      ActiveSupport::Notifications.unsubscribe(sub)
    end
  end

  after do
    @subscriptions.each do |event_name, _sub|
      # Re-register the subscriber
      WikiLinkExtractionSubscriber.subscribe(event_name)
    end
  end

  describe "#call" do
    # ── Task 2.5: Extraction of [[Title]] patterns ──

    context "when body contains a single wiki-link" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Meeting Notes") }

      before { source.update!(body: "See [[Meeting Notes]] for details") }

      it "creates a DocumentLink to the target document" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(1)
        expect(source.linked_documents).to contain_exactly(target)
      end
    end

    context "when body contains multiple wiki-links" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target_a) { create(:document, title: "Alpha") }
      let!(:target_b) { create(:document, title: "Beta") }

      before { source.update!(body: "Links to [[Alpha]] and [[Beta]]") }

      it "creates DocumentLinks to all target documents" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(2)
        expect(source.linked_documents).to contain_exactly(target_a, target_b)
      end
    end

    context "when body contains duplicate wiki-links" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Alpha") }

      before { source.update!(body: "First [[Alpha]] then again [[Alpha]]") }

      it "creates only one DocumentLink" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(1)
      end
    end

    context "when body contains nested brackets" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Outer") }

      before { source.update!(body: "Text [[[Outer]]] end") }

      it "extracts the innermost title" do
        described_class.new(source).call

        expect(source.linked_documents).to contain_exactly(target)
      end
    end

    context "when body has no wiki-links" do
      let!(:source) { create(:document, title: "Source") }

      before { source.update!(body: "No links here") }

      it "creates no DocumentLinks" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(0)
      end
    end

    context "when body is blank" do
      let!(:source) { create(:document, title: "Source") }

      it "creates no DocumentLinks" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(0)
      end
    end

    # ── Task 2.6: Case-insensitive matching, self-reference, unresolvable ──

    context "case-insensitive matching" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Meeting Notes") }

      before { source.update!(body: "See [[meeting notes]]") }

      it "resolves the title case-insensitively" do
        described_class.new(source).call

        expect(source.linked_documents).to contain_exactly(target)
      end
    end

    context "self-reference skipping" do
      let!(:source) { create(:document, title: "My Note") }

      before { source.update!(body: "I refer to [[My Note]]") }

      it "does not create a self-referencing link" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(0)
      end
    end

    context "unresolvable links" do
      let!(:source) { create(:document, title: "Source") }

      before { source.update!(body: "See [[Nonexistent Note]]") }

      it "does not create a DocumentLink for unresolvable titles" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(0)
      end
    end

    context "mix of resolvable and unresolvable links" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Alpha") }

      before { source.update!(body: "See [[Alpha]] and [[Ghost]]") }

      it "creates links only for resolvable titles" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(1)
        expect(source.linked_documents).to contain_exactly(target)
      end
    end

    # ── Task 2.7: Link sync — old removed, new created, idempotent ──

    context "link sync: old links removed" do
      let!(:source) { create(:document, title: "Source") }
      let!(:old_target) { create(:document, title: "Old Target") }
      let!(:new_target) { create(:document, title: "New Target") }

      before do
        create(:document_link, source_document: source, target_document: old_target)
        source.update!(body: "Now links to [[New Target]]")
      end

      it "removes the old link and creates the new one" do
        described_class.new(source).call

        expect(source.reload.linked_documents).to contain_exactly(new_target)
      end
    end

    context "link sync: idempotent on re-save" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Target") }

      before { source.update!(body: "See [[Target]]") }

      it "produces the same links when called multiple times" do
        described_class.new(source).call
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(1)
        expect(source.linked_documents).to contain_exactly(target)
      end
    end

    context "link sync: all links removed when body cleared" do
      let!(:source) { create(:document, title: "Source") }
      let!(:target) { create(:document, title: "Target") }

      before do
        create(:document_link, source_document: source, target_document: target)
        source.update!(body: "No links anymore")
      end

      it "removes all outgoing links" do
        described_class.new(source).call

        expect(source.outgoing_links.count).to eq(0)
      end
    end
  end
end
