require "active_storage/service"

module ActiveStorage
  class Service
    class UnifiedStorageService < Service
      def initialize(**config)
        @namespace = (config[:namespace] || :files).to_sym
      end

      def upload(key, io, checksum: nil, **)
        if (adapter = cloud_adapter_if_active)
          instrument :upload, key: key, checksum: checksum do
            temp = Tempfile.new([ "as_upload", File.extname(key) ])
            temp.binmode
            IO.copy_stream(io, temp)
            temp.close

            adapter.upload(temp.path, key, namespace: @namespace)
          ensure
            temp&.close!
          end
        else
          disk_service.upload(key, io, checksum: checksum)
        end
      end

      def download(key, &block)
        if (adapter = cloud_adapter_if_active)
          begin
            download_from_cloud(adapter, key, &block)
          rescue => e
            # Fallback to disk for files not yet migrated
            raise unless disk_service.exist?(key)
            disk_service.download(key, &block)
          end
        else
          disk_service.download(key, &block)
        end
      end

      def download_chunk(key, range)
        if (adapter = cloud_adapter_if_active)
          begin
            instrument :download_chunk, key: key, range: range do
              tempfile = adapter.download(key, namespace: @namespace)
              begin
                tempfile.seek(range.begin)
                tempfile.read(range.size)
              ensure
                tempfile.close!
              end
            end
          rescue => e
            raise unless disk_service.exist?(key)
            disk_service.download_chunk(key, range)
          end
        else
          disk_service.download_chunk(key, range)
        end
      end

      def delete(key)
        if (adapter = cloud_adapter_if_active)
          instrument :delete, key: key do
            adapter.delete(key, namespace: @namespace)
          end
          # Also remove from disk if it exists (cleanup after migration)
          disk_service.delete(key) if disk_service.exist?(key)
        else
          disk_service.delete(key)
        end
      end

      def delete_prefixed(prefix)
        if (adapter = cloud_adapter_if_active)
          instrument :delete_prefixed, prefix: prefix do
            adapter.list(namespace: @namespace).each do |file_key|
              adapter.delete(file_key, namespace: @namespace) if file_key.start_with?(prefix)
            end
          end
        else
          disk_service.delete_prefixed(prefix)
        end
      end

      def exist?(key)
        if (adapter = cloud_adapter_if_active)
          instrument :exist, key: key do |payload|
            answer = adapter.exist?(key, namespace: @namespace) || disk_service.exist?(key)
            payload[:exist] = answer
            answer
          end
        else
          disk_service.exist?(key)
        end
      end

      def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
        if (adapter = cloud_adapter_if_active)
          instrument :url, key: key do |payload|
            url = adapter.url(key, namespace: @namespace, expires_in: expires_in)
            payload[:url] = url
            url
          end
        else
          disk_service.url_for_direct_upload(key, expires_in: expires_in, content_type: content_type,
            content_length: content_length, checksum: checksum, custom_metadata: custom_metadata)
        end
      end

      def headers_for_direct_upload(key, content_type:, checksum:, **)
        { "Content-Type" => content_type, "Content-MD5" => checksum }
      end

      private

      def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
        generate_url(key, expires_in: expires_in, filename: filename, content_type: content_type, disposition: disposition)
      end

      def public_url(key, filename:, content_type: nil, disposition: :attachment, **)
        generate_url(key, expires_in: nil, filename: filename, content_type: content_type, disposition: disposition)
      end

      def generate_url(key, expires_in:, filename:, content_type:, disposition:)
        content_disposition = content_disposition_with(type: disposition, filename: filename)
        verified_key_with_expiration = ActiveStorage.verifier.generate(
          {
            key: key,
            disposition: content_disposition,
            content_type: content_type,
            service_name: name
          },
          expires_in: expires_in,
          purpose: :blob_key
        )

        if url_options.blank?
          raise ArgumentError, "Cannot generate URL for #{filename} using Unified service, please set ActiveStorage::Current.url_options."
        end

        url_helpers.rails_disk_service_url(verified_key_with_expiration, filename: filename, **url_options)
      end

      def download_from_cloud(adapter, key, &block)
        if block_given?
          instrument :streaming_download, key: key do
            tempfile = adapter.download(key, namespace: @namespace)
            begin
              while (chunk = tempfile.read(5.megabytes))
                yield chunk
              end
            ensure
              tempfile.close!
            end
          end
        else
          instrument :download, key: key do
            tempfile = adapter.download(key, namespace: @namespace)
            begin
              tempfile.read
            ensure
              tempfile.close!
            end
          end
        end
      end

      # Returns cloud adapter if a cloud provider is configured, nil otherwise.
      # Single DB query per call (replaces separate cloud_mode? + cloud_adapter).
      def cloud_adapter_if_active
        setting = StorageSetting.active_setting
        return nil if setting.nil? || setting.provider == "local"

        oauth = OAuthManager.new
        setting = oauth.ensure_fresh_token!(setting) if oauth.oauth_provider?(setting.provider)
        StorageAdapter.build(setting.provider, setting.config_data)
      rescue ActiveRecord::ActiveRecordError
        nil
      end

      def disk_service
        @disk_service ||= ActiveStorage::Service::DiskService.new(root: Rails.root.join("storage"))
      end

      def url_helpers
        @url_helpers ||= Rails.application.routes.url_helpers
      end

      def url_options
        ActiveStorage::Current.url_options
      end
    end
  end
end
