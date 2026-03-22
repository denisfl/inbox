module StorageAdapter
  class GoogleDrive < Base
    API_URL = "https://www.googleapis.com/drive/v3".freeze
    UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3".freeze
    ROOT_FOLDER_NAME = "Inbox".freeze
    FOLDER_MIME = "application/vnd.google-apps.folder".freeze

    def initialize(config: {})
      @access_token = config["access_token"] || config[:access_token]
      @folder_ids = config["folder_ids"] || config[:folder_ids] || {}
    end

    def upload(file_path, key, namespace: :files)
      folder_id = ensure_namespace_folder!(namespace)

      # Check if file already exists (for overwrite)
      existing = find_file(key, folder_id)

      if existing
        update_file(existing["id"], file_path)
      else
        create_file(key, file_path, folder_id)
      end

      key
    end

    def download(key, namespace: :files)
      folder_id = namespace_folder_id(namespace)
      file = find_file(key, folder_id)
      raise ApiError, "File not found: #{key}" unless file

      response = api_get("/files/#{file["id"]}?alt=media")

      tempfile = Tempfile.new([ "gdrive_download", File.extname(key) ])
      tempfile.binmode
      tempfile.write(response.body.to_s)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      folder_id = namespace_folder_id(namespace)
      file = find_file(key, folder_id)
      return unless file

      HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .delete("#{API_URL}/files/#{file["id"]}")
    end

    def list(namespace: :files)
      folder_id = namespace_folder_id(namespace)
      return [] unless folder_id

      query = "'#{folder_id}' in parents and trashed = false"
      results = []
      page_token = nil

      loop do
        params = { q: query, fields: "nextPageToken,files(id,name)", pageSize: 1000 }
        params[:pageToken] = page_token if page_token

        body = api_json("/files", params: params)
        files = body["files"] || []
        results.concat(files.map { |f| f["name"] })

        page_token = body["nextPageToken"]
        break unless page_token
      end

      results
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      folder_id = namespace_folder_id(namespace)
      file = find_file(key, folder_id)
      raise ApiError, "File not found: #{key}" unless file

      "#{API_URL}/files/#{file["id"]}?alt=media"
    end

    def test_connection
      test_key = ".storage_test_#{SecureRandom.hex(4)}"
      folder_id = ensure_namespace_folder!(:files)

      # Upload test file
      create_file(test_key, nil, folder_id, content: "ok")

      # Find and download it
      file = find_file(test_key, folder_id)
      raise ApiError, "Test file not found after upload" unless file

      response = api_get("/files/#{file["id"]}?alt=media")
      raise ApiError, "Test file content mismatch" unless response.body.to_s == "ok"

      # Delete it
      HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .delete("#{API_URL}/files/#{file["id"]}")

      { ok: true }
    rescue => e
      { ok: false, error: e.message }
    end

    # Returns folder IDs for persisting in StorageSetting config
    def folder_ids
      @folder_ids.dup
    end

    class ApiError < StandardError; end

    private

    def namespace_folder_id(namespace)
      @folder_ids[namespace.to_s]
    end

    def ensure_namespace_folder!(namespace)
      cached = namespace_folder_id(namespace)
      return cached if cached

      root_id = ensure_folder!(ROOT_FOLDER_NAME, "root")
      folder_id = ensure_folder!(namespace.to_s, root_id)

      @folder_ids[namespace.to_s] = folder_id
      folder_id
    end

    def ensure_folder!(name, parent_id)
      # Search for existing folder
      query = "name = '#{name}' and '#{parent_id}' in parents and mimeType = '#{FOLDER_MIME}' and trashed = false"
      body = api_json("/files", params: { q: query, fields: "files(id,name)", pageSize: 1 })
      files = body["files"] || []
      return files.first["id"] if files.any?

      # Create folder
      metadata = { name: name, mimeType: FOLDER_MIME, parents: [ parent_id ] }
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "application/json")
        .post("#{API_URL}/files", body: metadata.to_json)

      result = parse_response!(response)
      result["id"]
    end

    def find_file(name, folder_id)
      return nil unless folder_id

      query = "name = '#{name}' and '#{folder_id}' in parents and trashed = false"
      body = api_json("/files", params: { q: query, fields: "files(id,name)", pageSize: 1 })
      (body["files"] || []).first
    end

    def create_file(name, file_path, folder_id, content: nil)
      metadata = { name: name, parents: [ folder_id ] }
      body = content || File.binread(file_path)

      boundary = "StorageAdapter#{SecureRandom.hex(8)}"
      multipart = build_multipart(boundary, metadata, body)

      response = HTTP.timeout(60)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "multipart/related; boundary=#{boundary}")
        .post("#{UPLOAD_URL}/files?uploadType=multipart", body: multipart)

      parse_response!(response)
    end

    def update_file(file_id, file_path)
      body = File.binread(file_path)

      response = HTTP.timeout(60)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "application/octet-stream")
        .patch("#{UPLOAD_URL}/files/#{file_id}?uploadType=media", body: body)

      parse_response!(response)
    end

    def build_multipart(boundary, metadata, body)
      parts = []
      parts << "--#{boundary}\r\n"
      parts << "Content-Type: application/json; charset=UTF-8\r\n\r\n"
      parts << metadata.to_json
      parts << "\r\n--#{boundary}\r\n"
      parts << "Content-Type: application/octet-stream\r\n\r\n"
      parts << body
      parts << "\r\n--#{boundary}--"
      parts.join
    end

    def api_json(path, params: {})
      query_string = URI.encode_www_form(params)
      url = "#{API_URL}#{path}"
      url += "?#{query_string}" unless query_string.empty?

      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .get(url)

      parse_response!(response)
    end

    def api_get(path)
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .get("#{API_URL}#{path}")

      if response.status >= 400
        body = JSON.parse(response.body.to_s) rescue {}
        error_msg = body.dig("error", "message") || "HTTP #{response.status}"
        raise ApiError, error_msg
      end

      response
    end

    def parse_response!(response)
      body = JSON.parse(response.body.to_s)

      if response.status >= 400
        error_msg = body.dig("error", "message") || "HTTP #{response.status}"
        raise ApiError, error_msg
      end

      body
    rescue JSON::ParserError
      raise ApiError, "Invalid response: HTTP #{response.status}"
    end
  end
end
