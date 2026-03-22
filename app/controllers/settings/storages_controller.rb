module Settings
  class StoragesController < ApplicationController
    def show
      @setting = StorageSetting.active_setting || StorageSetting.new(provider: "local")
      @migration = StorageMigration.active.last || StorageMigration.order(created_at: :desc).first
    end

    def update
      @setting = StorageSetting.active_setting || StorageSetting.new

      @setting.provider = storage_params[:provider]
      @setting.config_data = config_params
      @setting.active = true
      @setting.status = "unchecked"

      if @setting.save
        redirect_to settings_storage_path, notice: "Storage settings saved."
      else
        render :show, status: :unprocessable_content
      end
    end

    def test_connection
      @setting = StorageSetting.active_setting

      if @setting.nil?
        redirect_to settings_storage_path, alert: "No storage configured. Save settings first."
        return
      end

      adapter = StorageAdapter.resolve
      result = adapter.test_connection

      @setting.update!(status: "ok", last_checked_at: Time.current)
      redirect_to settings_storage_path, notice: "Connection successful."
    rescue => e
      @setting&.update(status: "error", last_checked_at: Time.current)
      redirect_to settings_storage_path, alert: "Connection failed: #{e.message}"
    end

    def start_migration
      @setting = StorageSetting.active_setting

      if @setting.nil? || @setting.provider == "local"
        redirect_to settings_storage_path, alert: "Configure a cloud provider first."
        return
      end

      if StorageMigration.active.exists?
        redirect_to settings_storage_path, alert: "A migration is already in progress."
        return
      end

      from_provider = params[:from_provider] || "local"
      to_provider = @setting.provider

      migration = StorageMigration.create!(
        from_provider: from_provider,
        to_provider: to_provider,
        status: "pending"
      )

      StorageMigrationJob.perform_later(migration.id)
      redirect_to settings_storage_path, notice: "Migration started."
    end

    def cancel_migration
      migration = StorageMigration.active.last

      if migration
        migration.update!(status: "cancelled", completed_at: Time.current)
        redirect_to settings_storage_path, notice: "Migration cancelled."
      else
        redirect_to settings_storage_path, alert: "No active migration to cancel."
      end
    end

    private

    def storage_params
      params.require(:storage_setting).permit(:provider)
    end

    def config_params
      params.fetch(:config, {}).permit(
        :access_key_id, :secret_access_key, :region, :bucket, :endpoint
      ).to_h.compact_blank
    end
  end
end
