require "rails_helper"

RSpec.describe StorageSetting do
  describe "validations" do
    it "is valid with a valid provider" do
      setting = StorageSetting.new(provider: "local")
      expect(setting).to be_valid
    end

    it "is invalid without a provider" do
      setting = StorageSetting.new(provider: nil)
      expect(setting).not_to be_valid
      expect(setting.errors[:provider]).to include("can't be blank")
    end

    it "is invalid with an unknown provider" do
      setting = StorageSetting.new(provider: "ftp")
      expect(setting).not_to be_valid
      expect(setting.errors[:provider]).to include("is not included in the list")
    end

    it "accepts all valid providers" do
      StorageSetting::VALID_PROVIDERS.each do |p|
        setting = StorageSetting.new(provider: p)
        expect(setting).to be_valid, "Expected provider '#{p}' to be valid"
      end
    end
  end

  describe ".active_setting" do
    it "returns the most recently updated active setting" do
      old = StorageSetting.create!(provider: "local", active: true, updated_at: 1.day.ago)
      recent = StorageSetting.create!(provider: "s3", active: true)

      expect(StorageSetting.active_setting).to eq(recent)
    end

    it "returns nil when no active settings exist" do
      StorageSetting.create!(provider: "local", active: false)

      expect(StorageSetting.active_setting).to be_nil
    end

    it "returns nil when no settings exist" do
      expect(StorageSetting.active_setting).to be_nil
    end
  end

  describe "#config_data / #config_data=" do
    it "stores and retrieves JSON config" do
      setting = StorageSetting.create!(provider: "s3")
      setting.config_data = { "bucket" => "test", "region" => "us-west-2" }
      setting.save!
      setting.reload

      expect(setting.config_data).to eq({ "bucket" => "test", "region" => "us-west-2" })
    end

    it "returns empty hash when config_encrypted is nil" do
      setting = StorageSetting.new(provider: "local")
      expect(setting.config_data).to eq({})
    end

    it "returns empty hash when config_encrypted is blank" do
      setting = StorageSetting.new(provider: "local", config_encrypted: "")
      expect(setting.config_data).to eq({})
    end
  end
end
