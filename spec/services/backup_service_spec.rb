require "rails_helper"

RSpec.describe BackupService do
  let(:storage) { instance_double(StorageAdapter::Local) }
  let(:service) { described_class.new(storage: storage) }
  let(:temp_path) { Rails.root.join("tmp", "backups", "test_backup.sql.gz") }

  before do
    FileUtils.mkdir_p(Rails.root.join("tmp", "backups"))
  end

  describe "#perform" do
    before do
      allow(service).to receive(:dump_and_compress).and_return(temp_path)
      allow(storage).to receive(:upload).and_return("/backups/backup_test.sql.gz")
      allow(service).to receive(:cleanup_temp)
      allow(service).to receive(:cleanup_retention)

      # Create a fake temp file for size measurement
      FileUtils.touch(temp_path)
      File.write(temp_path, "x" * 1024)
    end

    after do
      FileUtils.rm_f(temp_path)
    end

    it "creates a BackupRecord with running status" do
      service.perform

      record = BackupRecord.last
      expect(record.status).to eq("completed")
      expect(record.started_at).to be_present
      expect(record.completed_at).to be_present
      expect(record.size_bytes).to eq(1024)
    end

    it "calls storage upload" do
      service.perform
      expect(storage).to have_received(:upload)
    end

    it "cleans up temp file and runs retention" do
      service.perform
      expect(service).to have_received(:cleanup_temp)
      expect(service).to have_received(:cleanup_retention)
    end

    context "when dump fails" do
      before do
        allow(service).to receive(:dump_and_compress).and_raise(RuntimeError, "dump failed")
      end

      it "records failure in BackupRecord" do
        expect { service.perform }.to raise_error(RuntimeError, "dump failed")

        record = BackupRecord.last
        expect(record.status).to eq("failed")
        expect(record.error_message).to include("dump failed")
      end
    end

    context "when upload fails" do
      before do
        allow(storage).to receive(:upload).and_raise(Errno::ECONNREFUSED, "connection refused")
      end

      it "records failure in BackupRecord" do
        expect { service.perform }.to raise_error(Errno::ECONNREFUSED)

        record = BackupRecord.last
        expect(record.status).to eq("failed")
        expect(record.error_message).to include("ECONNREFUSED")
      end
    end
  end

  describe "#cleanup_retention" do
    let!(:recent) { create(:backup_record, status: "completed", created_at: 5.days.ago, storage_path: "/backups/recent.sql.gz") }
    let!(:old) { create(:backup_record, :old, status: "completed", storage_path: "/backups/old.sql.gz") }

    before do
      allow(storage).to receive(:delete)
    end

    it "deletes old backup records" do
      service.cleanup_retention

      expect(BackupRecord.find_by(id: old.id)).to be_nil
      expect(BackupRecord.find_by(id: recent.id)).to be_present
    end

    it "calls storage delete for old backups" do
      service.cleanup_retention

      expect(storage).to have_received(:delete).with("old.sql.gz", namespace: :backups)
    end
  end
end
