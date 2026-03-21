require "rails_helper"
require "rake"

RSpec.describe "rake db:integrity_check", type: :task do
  # Suppress wiki-link extraction subscriber
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

  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?("db:integrity_check")
  end

  it "passes with clean database" do
    expect {
      begin
        Rake::Task["db:integrity_check"].reenable
        Rake::Task["db:integrity_check"].invoke
      rescue SystemExit => e
        @exit_code = e.status
      end
    }.to output(/Integrity check passed/).to_stdout

    expect(@exit_code).to eq(0)
  end

  it "fails when orphan record exists" do
    # Stub find_orphans at the top level to simulate an orphan found in document_links
    allow_any_instance_of(Object).to receive(:find_orphans).and_wrap_original do |method, table, fk_column, ref_table|
      if table == "document_links" && fk_column == "target_document_id"
        [ { table: table, record_id: 999, fk_column: fk_column, references: ref_table, missing_id: 99999 } ]
      else
        method.call(table, fk_column, ref_table)
      end
    end

    expect {
      begin
        Rake::Task["db:integrity_check"].reenable
        Rake::Task["db:integrity_check"].invoke
      rescue SystemExit => e
        @exit_code = e.status
      end
    }.to output(/Integrity check FAILED/).to_stdout

    expect(@exit_code).to eq(1)
  end
end
