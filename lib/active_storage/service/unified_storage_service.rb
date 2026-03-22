require "active_storage/service"

module ActiveStorage
  class Service
    class UnifiedStorageService < Service
      def initialize(**config)
        @namespace = (config[:namespace] || :files).to_sym
      end

      def upload(key, io, checksum: nil, **)
        if cloud_mode?
          instrument :upload, key: key, checksum: checksum do
            temp = Tempfile.new([ "as_upload", File.extname(key) ])
            temp.binmode
            IO.copy_stream(io, temp)
            temp.close

            cloud_adapter.upload(temp.path, key, namespace: @namespace)
          ensure
            temp&.close!
          end
        else
          disk_service.upload(key, io, checksum: checksum)
        end
      end

      def download(key, &block)
        if cloud_mode?
          begin
            download_from_cloud(key, &block)
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
        if cloud_mode?
          begin
            instrument :download_chunk, key: key, range: range do
              tempfile = cloud_adapter.download(key, namespace: @namespace)
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
        if cloud_mode?
          instrument :delete, key: key do
            cloud_adapter.delete(key, namespace: @namespace)
          end
          # Also remove from disk if it exists (cleanup after migration)
          disk_service.delete(key) if disk_service.exist?(key)
        else
          disk_service.delete(key)
        end
      end

      def delete_prefixed(prefix)
        if cloud_mode?
          instrument :delete_prefixed, prefix: prefix do
            cloud_adapter.list(namespace: @namespace).each do |file_key|
              cloud_adapter.delete(file_key, namespace: @namespace) if file_key.start_with?(prefix)
            end
          end
        else
          disk_service.delete_prefixed(prefix)
        end
      end

      def exist?(key)
        if cloud_mode?
          instrument :exist, key: key do |payload|
            answer = cloud_adapter.list(namespace: @namespace).include?(key) || disk_service.exist?(key)
            payload[:exist] = answer
            answer
          end
        else
          disk_service.exist?(key)
        end
      end

      def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
        if cloud_mode?
          instrument :url, key: key do |payload|
            url = cloud_adapter.url(key, namespace: @namespace, expires_in: expires_in)
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

      def download_from_cloud(key, &block)
        if block_given?
          instrument :streaming_download, key: key do
            tempfile = cloud_adapter.download(key, namespace: @namespace)
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
            tempfile = cloud_adapter.download(key, namespace: @namespace)
            begin
              tempfile.read
            ensure
              tempfile.close!
            end
          end
        end
      end

      def cloud_mode?
        setting = StorageSetting.active_setting
        setting && setting.provider != "local"
      rescue
        false
      end

      def cloud_adapter
        StorageAdapter.resolve
      end

      def disk_service
        @disk_service ||= ActiveStorage::Service::DiskService.new(root: Rails.root.join("storage"))
      end
    end
  end
end
