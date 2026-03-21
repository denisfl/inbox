# frozen_string_literal: true

require "rails_helper"

RSpec.describe DomainEvents, type: :model do
  describe "event publishing" do
    it "publishes document.created on create" do
      events = []
      sub = ActiveSupport::Notifications.subscribe("document.created") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      create(:document, title: "Test Doc")

      expect(events.size).to eq(1)
      expect(events.first.payload[:model_class]).to eq("Document")
      expect(events.first.payload[:action]).to eq("created")
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "publishes document.updated on update" do
      document = create(:document, title: "Original")
      events = []
      sub = ActiveSupport::Notifications.subscribe("document.updated") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      document.update!(title: "Updated")

      expect(events.size).to eq(1)
      expect(events.first.payload[:model_id]).to eq(document.id)
      expect(events.first.payload[:action]).to eq("updated")
      expect(events.first.payload[:changes]).to include("title")
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "publishes document.deleted on destroy" do
      document = create(:document, title: "To Delete")
      events = []
      sub = ActiveSupport::Notifications.subscribe("document.deleted") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      document.destroy!

      expect(events.size).to eq(1)
      expect(events.first.payload[:action]).to eq("deleted")
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "publishes task.created on create" do
      events = []
      sub = ActiveSupport::Notifications.subscribe("task.created") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      task = create(:task, title: "New Task")

      expect(events.size).to eq(1)
      expect(events.first.payload[:model_class]).to eq("Task")
      expect(events.first.payload[:model_id]).to eq(task.id)
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "publishes task.completed via complete!" do
      task = create(:task, title: "Complete Me")
      events = []
      sub = ActiveSupport::Notifications.subscribe("task.completed") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      task.complete!

      expect(events.size).to eq(1)
      expect(events.first.payload[:action]).to eq("completed")
      expect(events.first.payload[:model_id]).to eq(task.id)
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    it "publishes task.uncompleted via uncomplete!" do
      task = create(:task, :completed, title: "Uncomplete Me")
      events = []
      sub = ActiveSupport::Notifications.subscribe("task.uncompleted") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      task.uncomplete!

      expect(events.size).to eq(1)
      expect(events.first.payload[:action]).to eq("uncompleted")
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end
  end

  describe "event payload" do
    it "contains all expected keys" do
      events = []
      sub = ActiveSupport::Notifications.subscribe("document.created") do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      create(:document, title: "Payload Test")

      payload = events.first.payload
      expect(payload).to include(:model_class, :model_id, :action, :changes, :timestamp)
      expect(payload[:model_class]).to eq("Document")
      expect(payload[:action]).to eq("created")
      expect(payload[:timestamp]).to be_a(Time)
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end
  end
end
