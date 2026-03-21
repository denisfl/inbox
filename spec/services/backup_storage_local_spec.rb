require "rails_helper"

RSpec.describe BackupStorage::Local do
  let(:tmp_dir) { Rails.root.join("tmp", "test_backups_#{SecureRandom.hex(4)}") }
  let(:storage) { described_class.new(path: tmp_dir.to_s) }

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#upload" do
    it "copies the file to the storage path" do
      source = Tempfile.new([ "backup", ".sql.gz" ])
      source.write("test backup data")
      source.close

      result = storage.upload(source.path, "backup_20260321.sql.gz")

      expect(File.exist?(tmp_dir.join("backup_20260321.sql.gz"))).to be true
      expect(result).to eq(tmp_dir.join("backup_20260321.sql.gz").to_s)
    ensure
      source&.unlink
    end

    it "creates the directory if it does not exist" do
      source = Tempfile.new([ "backup", ".sql.gz" ])
      source.write("data")
      source.close

      expect(tmp_dir).not_to exist
      storage.upload(source.path, "test.sql.gz")
      expect(tmp_dir).to exist
    ensure
      source&.unlink
    end
  end

  describe "#delete" do
    it "removes the specified file" do
      FileUtils.mkdir_p(tmp_dir)
      file_path = tmp_dir.join("old.sql.gz")
      FileUtils.touch(file_path)

      storage.delete("old.sql.gz")

      expect(File.exist?(file_path)).to be false
    end

    it "does not raise if file does not exist" do
      expect { storage.delete("nonexistent.sql.gz") }.not_to raise_error
    end
  end

  describe "#list" do
    it "returns sorted list of .gz files" do
      FileUtils.mkdir_p(tmp_dir)
      FileUtils.touch(tmp_dir.join("backup_20260320.sql.gz"))
      FileUtils.touch(tmp_dir.join("backup_20260321.sql.gz"))
      FileUtils.touch(tmp_dir.join("not_a_backup.txt"))

      result = storage.list

      expect(result).to eq([ "backup_20260320.sql.gz", "backup_20260321.sql.gz" ])
    end

    it "returns empty array if directory does not exist" do
      expect(storage.list).to eq([])
    end
  end
end
