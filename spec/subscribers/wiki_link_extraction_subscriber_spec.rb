# frozen_string_literal: true

require "rails_helper"

RSpec.describe WikiLinkExtractionSubscriber do
  describe "#call" do
    it "extracts wiki-links when document.created event fires" do
      target = create(:document, title: "Target for Extract")
      source = create(:document, title: "Source for Extract")
      source.update!(body: "Link to [[Target for Extract]]")

      # The subscriber is registered in the initializer and fires on document.created/updated
      # via DomainEvents after_save hooks. Since we used create/update above,
      # the events already fired. Verify the links were extracted.
      source.reload
      expect(source.linked_documents).to include(target)
    end

    it "extracts wiki-links when document.updated event fires" do
      target = create(:document, title: "Linked Updated Doc")
      source = create(:document, title: "Source Updated Doc")

      # Initially no links
      expect(source.outgoing_links.count).to eq(0)

      # Update body to include a wiki-link
      source.update!(body: "See [[Linked Updated Doc]]")

      source.reload
      expect(source.linked_documents).to include(target)
    end
  end
end

RSpec.describe BaseSubscriber do
  describe "error isolation" do
    it "logs error and does not raise when subscriber fails" do
      # Create a failing subscriber
      failing_subscriber = Class.new(BaseSubscriber) do
        def call(_event)
          raise "boom"
        end
      end

      # Subscribe it
      failing_subscriber.subscribe("test.isolation_event")

      # Should not raise — error is caught and logged
      expect(Rails.logger).to receive(:error).with(/failed.*boom/)

      expect {
        ActiveSupport::Notifications.instrument("test.isolation_event", { test: true })
      }.not_to raise_error
    ensure
      ActiveSupport::Notifications.unsubscribe("test.isolation_event")
    end

    it "one subscriber failing does not affect others" do
      results = []

      failing_sub = Class.new(BaseSubscriber) do
        define_method(:call) { |_event| raise "fail" }
      end

      passing_sub = Class.new(BaseSubscriber) do
        define_method(:call) { |_event| results << :ok }
      end

      failing_sub.subscribe("test.multi_event")
      passing_sub.subscribe("test.multi_event")

      allow(Rails.logger).to receive(:error)

      ActiveSupport::Notifications.instrument("test.multi_event", { test: true })

      expect(results).to eq([ :ok ])
    ensure
      ActiveSupport::Notifications.unsubscribe("test.multi_event")
    end
  end
end
