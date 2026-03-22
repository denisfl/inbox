require "rails_helper"

RSpec.describe StorageAdapter::Local do
  let(:tmp_dir) { Rails.root.join("tmp", "test_storage_#{SecureRandom.hex(4)}") }
  let(:adapter) { described_class.new(base_path: tmp_dir.to_s) }

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#upload" do
    it "copies file to namespace directory" do
      source = Tempfile.new([ "test", ".txt" ])
      source.write("hello world")
      source.close

      result = adapter.upload(source.path, "file.txt", namespace: :backups)

      expect(File.exist?(tmp_dir.join("backups", "file.txt"))).to be true
      expect(File.read(tmp_dir.join("backups", "file.txt"))).to eq("hello world")
      expect(result).to include("backups/file.txt")
    ensure
      source&.unlink
    end

    it "creates namespace directory if it does not exist" do
      source = Tempfile.new([ "test", ".txt" ])
      source.write("data")
      source.close

      expect(tmp_dir.join("files")).not_to exist
      adapter.upload(source.path, "test.txt", namespace: :files)
      expect(tmp_dir.join("files")).to exist
    ensure
      source&.unlink
    end

    it "uses default namespace :files" do
      source = Tempfile.new([ "test", ".txt" ])
      source.write("data")
      source.close

      adapter.upload(source.path, "default.txt")

      expect(File.exist?(tmp_dir.join("files", "default.txt"))).to be true
    ensure
      source&.unlink
    end
  end

  describe "#download" do
    it "returns a Tempfile with file contents" do
      FileUtils.mkdir_p(tmp_dir.join("backups"))
      File.write(tmp_dir.join("backups", "file.txt"), "backup data")

      tempfile = adapter.download("file.txt", namespace: :backups)

      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq("backup data")
    ensure
      tempfile&.close!
    end

    it "raises when file does not exist" do
      expect { adapter.download("missing.txt", namespace: :backups) }.to raise_error(RuntimeError, /File not found/)
    end
  end

  describe "#delete" do
    it "removes the specified file" do
      FileUtils.mkdir_p(tmp_dir.join("backups"))
      File.write(tmp_dir.join("backups", "old.txt"), "data")

      adapter.delete("old.txt", namespace: :backups)

      expect(File.exist?(tmp_dir.join("backups", "old.txt"))).to be false
    end

    it "does not raise if file does not exist" do
      expect { adapter.delete("nonexistent.txt", namespace: :backups) }.not_to raise_error
    end
  end

  describe "#list" do
    it "returns files in the namespace directory" do
      FileUtils.mkdir_p(tmp_dir.join("files"))
      File.write(tmp_dir.join("files", "a.txt"), "")
      File.write(tmp_dir.join("files", "b.txt"), "")

      result = adapter.list(namespace: :files)

      expect(result).to contain_exactly("a.txt", "b.txt")
    end

    it "returns empty array if namespace directory does not exist" do
      expect(adapter.list(namespace: :missing)).to eq([])
    end
  end

  describe "#url" do
    it "returns local filesystem path" do
      FileUtils.mkdir_p(tmp_dir.join("files"))
      File.write(tmp_dir.join("files", "photo.jpg"), "")

      result = adapter.url("photo.jpg", namespace: :files)

      expect(result).to eq(tmp_dir.join("files", "photo.jpg").to_s)
    end
  end

  describe "#test_connection" do
    it "returns ok when base path is writable" do
      result = adapter.test_connection
      expect(result).to eq({ ok: true })
    end
  end
end
