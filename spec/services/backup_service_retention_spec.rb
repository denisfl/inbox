require "rails_helper"

RSpec.describe "BackupService retention cleanup" do
  let(:storage) { instance_double(StorageAdapter::Local) }
  let(:service) { BackupService.new(storage: storage) }

  before do
    allow(storage).to receive(:delete)
  end

  describe "#cleanup_retention" do
    context "with mixed old and recent records" do
      let!(:recent1) { create(:backup_record, status: "completed", created_at: 5.days.ago, storage_path: "/backups/recent1.sql.gz") }
      let!(:recent2) { create(:backup_record, status: "completed", created_at: 10.days.ago, storage_path: "/backups/recent2.sql.gz") }
      let!(:old1) { create(:backup_record, :old, status: "completed", storage_path: "/backups/old1.sql.gz") }
      let!(:old2) { create(:backup_record, status: "completed", created_at: 60.days.ago, storage_path: "/backups/old2.sql.gz") }

      it "deletes only old records" do
        expect { service.cleanup_retention }.to change(BackupRecord, :count).by(-2)

        expect(BackupRecord.find_by(id: recent1.id)).to be_present
        expect(BackupRecord.find_by(id: recent2.id)).to be_present
        expect(BackupRecord.find_by(id: old1.id)).to be_nil
        expect(BackupRecord.find_by(id: old2.id)).to be_nil
      end

      it "calls storage delete for each old backup" do
        service.cleanup_retention

        expect(storage).to have_received(:delete).with("old1.sql.gz", namespace: :backups)
        expect(storage).to have_received(:delete).with("old2.sql.gz", namespace: :backups)
        expect(storage).not_to have_received(:delete).with("recent1.sql.gz", namespace: :backups)
      end
    end

    context "with no old records" do
      let!(:recent) { create(:backup_record, status: "completed", created_at: 1.day.ago, storage_path: "/backups/recent.sql.gz") }

      it "does not delete anything" do
        expect { service.cleanup_retention }.not_to change(BackupRecord, :count)
      end
    end

    context "when old record has nil storage_path" do
      let!(:old_no_path) { create(:backup_record, :old, status: "completed", storage_path: nil) }

      it "deletes the record without calling storage delete" do
        service.cleanup_retention

        expect(BackupRecord.find_by(id: old_no_path.id)).to be_nil
        expect(storage).not_to have_received(:delete)
      end
    end

    context "when storage delete fails" do
      let!(:old) { create(:backup_record, :old, status: "completed", storage_path: "/backups/old.sql.gz") }

      before do
        allow(storage).to receive(:delete).and_raise(Errno::ENOENT, "No such file")
      end

      it "still deletes the record and does not raise" do
        expect { service.cleanup_retention }.not_to raise_error

        expect(BackupRecord.find_by(id: old.id)).to be_nil
      end
    end

    context "with custom retention days via ENV" do
      let!(:ten_day_old) { create(:backup_record, status: "completed", created_at: 10.days.ago, storage_path: "/backups/ten.sql.gz") }

      before do
        allow(ENV).to receive(:fetch).with("BACKUP_RETENTION_DAYS", anything).and_return("7")
        allow(ENV).to receive(:fetch).with("BACKUP_STORAGE_TYPE", anything).and_return("local")
      end

      it "uses custom retention period" do
        service.cleanup_retention

        expect(BackupRecord.find_by(id: ten_day_old.id)).to be_nil
        expect(storage).to have_received(:delete).with("ten.sql.gz", namespace: :backups)
      end
    end

    context "only cleans up successful records" do
      let!(:old_failed) { create(:backup_record, :old, :failed, storage_path: "/backups/old_fail.sql.gz") }
      let!(:old_completed) { create(:backup_record, :old, status: "completed", storage_path: "/backups/old_ok.sql.gz") }

      it "does not delete failed records" do
        service.cleanup_retention

        expect(BackupRecord.find_by(id: old_failed.id)).to be_present
        expect(BackupRecord.find_by(id: old_completed.id)).to be_nil
      end
    end
  end
end
