require "rails_helper"

# Exercises the ActiveStorage service that backs both development and
# production (config.active_storage.service = :unified). It delegates to a
# cloud StorageAdapter when one is active, and falls back to local disk
# otherwise. There was no coverage here previously, which let a regression
# (uninitialized constant ActiveStorage::Service::DiskService) ship: the disk
# service class is only autoloaded when a Disk service is configured, which
# never happens in the :unified-only dev/prod setup.
RSpec.describe ActiveStorage::Service::UnifiedStorageService do
  let(:disk_root) { Rails.root.join("tmp", "unified_spec_#{SecureRandom.hex(4)}") }
  let(:disk) { ActiveStorage::Service::DiskService.new(root: disk_root.to_s) }
  let(:service) do
    described_class.new(namespace: :test_files).tap { |s| s.name = "unified" }
  end

  before { allow(service).to receive(:disk_service).and_return(disk) }
  after  { FileUtils.rm_rf(disk_root) }

  def upload(key, contents)
    service.upload(key, StringIO.new(contents), checksum: nil)
  end

  context "with no active cloud provider (local disk)" do
    before { allow(service).to receive(:cloud_adapter_if_active).and_return(nil) }

    it "round-trips upload, exist?, download and delete via disk" do
      upload("abc123", "hello local")

      expect(service.exist?("abc123")).to be true
      expect(service.download("abc123")).to eq("hello local")

      service.delete("abc123")
      expect(service.exist?("abc123")).to be false
    end

    it "exposes path_for so ActiveStorage::DiskController can serve the file" do
      upload("abc123", "served bytes")

      expect(service.path_for("abc123")).to eq(disk.path_for("abc123"))
      expect(File.read(service.path_for("abc123"))).to eq("served bytes")
    end

    it "builds a disk-service URL for serving" do
      ActiveStorage::Current.url_options = { host: "localhost", protocol: "http" }
      url = service.url("abc123", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("a.txt"),
        content_type: "text/plain", disposition: :inline)

      expect(url).to include("/rails/active_storage/disk/")
    ensure
      ActiveStorage::Current.url_options = nil
    end
  end

  context "with an active cloud provider" do
    let(:adapter) { instance_double("StorageAdapter::Dropbox") }

    before { allow(service).to receive(:cloud_adapter_if_active).and_return(adapter) }

    it "uploads through the cloud adapter, not the disk" do
      expect(adapter).to receive(:upload).with(kind_of(String), "cloudkey", namespace: :test_files)

      upload("cloudkey", "to the cloud")

      expect(disk.exist?("cloudkey")).to be false
    end

    it "redirects to the adapter's temporary URL instead of a disk URL" do
      allow(adapter).to receive(:url).with("cloudkey", namespace: :test_files, expires_in: 5.minutes)
        .and_return("https://dl.example.com/cloudkey")

      url = service.url("cloudkey", expires_in: 5.minutes, filename: ActiveStorage::Filename.new("a.txt"),
        content_type: "text/plain", disposition: :inline)

      expect(url).to eq("https://dl.example.com/cloudkey")
    end

    it "falls back to disk on cloud download errors for not-yet-migrated files" do
      disk.upload("legacy", StringIO.new("on disk"), checksum: nil)
      allow(adapter).to receive(:download).and_raise(StandardError, "404 from cloud")

      expect(service.download("legacy")).to eq("on disk")
    end
  end
end
