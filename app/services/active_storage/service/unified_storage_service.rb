require "active_storage/service"

module ActiveStorage
  class Service
    class UnifiedStorageService < Service
      def initialize(**config)
        @namespace = (config[:namespace] || :files).to_sym
      end

      def upload(key, io, checksum: nil, **)
        instrument :upload, key: key, checksum: checksum do
          temp = Tempfile.new([ "as_upload", File.extname(key) ])
          temp.binmode
          IO.copy_stream(io, temp)
          temp.close

          adapter.upload(temp.path, key, namespace: @namespace)
        ensure
          temp&.close!
        end
      end

      def download(key, &block)
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

      def download_chunk(key, range)
        instrument :download_chunk, key: key, range: range do
          tempfile = adapter.download(key, namespace: @namespace)
          begin
            tempfile.seek(range.begin)
            tempfile.read(range.size)
          ensure
            tempfile.close!
          end
        end
      end

      def delete(key)
        instrument :delete, key: key do
          adapter.delete(key, namespace: @namespace)
        end
      end

      def delete_prefixed(prefix)
        instrument :delete_prefixed, prefix: prefix do
          adapter.list(namespace: @namespace).each do |file_key|
            adapter.delete(file_key, namespace: @namespace) if file_key.start_with?(prefix)
          end
        end
      end

      def exist?(key)
        instrument :exist, key: key do |payload|
          answer = adapter.list(namespace: @namespace).include?(key)
          payload[:exist] = answer
          answer
        end
      end

      def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
        instrument :url, key: key do |payload|
          url = adapter.url(key, namespace: @namespace, expires_in: expires_in)
          payload[:url] = url
          url
        end
      end

      def headers_for_direct_upload(key, content_type:, checksum:, **)
        { "Content-Type" => content_type, "Content-MD5" => checksum }
      end

      private

      def adapter
        StorageAdapter.resolve
      end
    end
  end
end
