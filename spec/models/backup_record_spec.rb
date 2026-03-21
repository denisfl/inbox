require "rails_helper"

RSpec.describe BackupRecord, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:storage_type) }
    it { is_expected.to validate_presence_of(:started_at) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[running completed failed]) }
  end

  describe "scopes" do
    let!(:completed) { create(:backup_record, status: "completed", started_at: 2.hours.ago) }
    let!(:failed) { create(:backup_record, :failed, started_at: 1.hour.ago) }
    let!(:running) { create(:backup_record, :running, started_at: Time.current) }

    describe ".successful" do
      it "returns only completed records" do
        expect(described_class.successful).to eq([completed])
      end
    end

    describe ".failed" do
      it "returns only failed records" do
        expect(described_class.failed).to eq([failed])
      end
    end

    describe ".latest" do
      it "returns the most recent record by started_at" do
        expect(described_class.latest.first).to eq(running)
      end
    end

    describe ".older_than" do
      let!(:old_record) { create(:backup_record, :old) }

      it "returns records older than given days" do
        expect(described_class.older_than(30)).to include(old_record)
        expect(described_class.older_than(30)).not_to include(completed)
      end
    end
  end
end
