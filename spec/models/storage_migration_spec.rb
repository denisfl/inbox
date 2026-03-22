require "rails_helper"

RSpec.describe StorageMigration, type: :model do
  describe "validations" do
    it "requires from_provider" do
      migration = StorageMigration.new(to_provider: "s3")
      expect(migration).not_to be_valid
      expect(migration.errors[:from_provider]).to include("can't be blank")
    end

    it "requires to_provider" do
      migration = StorageMigration.new(from_provider: "local")
      expect(migration).not_to be_valid
      expect(migration.errors[:to_provider]).to include("can't be blank")
    end

    it "validates status inclusion" do
      migration = StorageMigration.new(from_provider: "local", to_provider: "s3", status: "bad")
      expect(migration).not_to be_valid
    end

    it "is valid with required attributes" do
      migration = StorageMigration.new(from_provider: "local", to_provider: "dropbox")
      expect(migration).to be_valid
    end
  end

  describe "#progress_percent" do
    it "returns 0 when total_items is 0" do
      migration = StorageMigration.new(total_items: 0, completed_items: 0)
      expect(migration.progress_percent).to eq(0)
    end

    it "calculates percentage correctly" do
      migration = StorageMigration.new(total_items: 10, completed_items: 3)
      expect(migration.progress_percent).to eq(30)
    end

    it "rounds to nearest integer" do
      migration = StorageMigration.new(total_items: 3, completed_items: 1)
      expect(migration.progress_percent).to eq(33)
    end
  end

  describe "#append_error" do
    it "appends error messages to error_log" do
      migration = StorageMigration.new
      migration.append_error("first error")
      migration.append_error("second error")
      expect(migration.error_log).to include("first error")
      expect(migration.error_log).to include("second error")
    end
  end

  describe "scopes" do
    it ".active returns pending and running migrations" do
      pending_m = StorageMigration.create!(from_provider: "local", to_provider: "s3", status: "pending")
      running_m = StorageMigration.create!(from_provider: "local", to_provider: "s3", status: "running")
      StorageMigration.create!(from_provider: "local", to_provider: "s3", status: "completed")
      StorageMigration.create!(from_provider: "local", to_provider: "s3", status: "failed")

      expect(StorageMigration.active).to contain_exactly(pending_m, running_m)
    end
  end
end
