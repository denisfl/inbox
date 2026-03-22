module StorageAdapter
  class Dropbox < Base
    BASE_URL = "https://api.dropboxapi.com/2".freeze
    CONTENT_URL = "https://content.dropboxapi.com/2".freeze
    ROOT_FOLDER = "/Apps/Inbox".freeze

    def initialize(config: {})
      @access_token = config["access_token"] || config[:access_token]
    end

    def upload(file_path, key, namespace: :files)
      path = dropbox_path(key, namespace)
      ensure_folder_exists!(namespace)

      body = File.binread(file_path)
      api_arg = { path: path, mode: "overwrite", autorename: false }

      content_request("/files/upload", body: body, api_arg: api_arg)
      path
    end

    def download(key, namespace: :files)
      path = dropbox_path(key, namespace)
      api_arg = { path: path }

      response = content_download("/files/download", api_arg: api_arg)

      tempfile = Tempfile.new([ "dropbox_download", File.extname(key) ])
      tempfile.binmode
      tempfile.write(response.body.to_s)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      path = dropbox_path(key, namespace)
      api_request("/files/delete_v2", path: path)
    end

    def list(namespace: :files)
      path = "#{ROOT_FOLDER}/#{namespace}"
      body = api_request("/files/list_folder", path: path)
      entries = body["entries"] || []

      results = entries.select { |e| e[".tag"] == "file" }.map do |entry|
        entry["name"]
      end

      # Handle pagination
      while body["has_more"]
        body = api_request("/files/list_folder/continue", cursor: body["cursor"])
        more = body["entries"] || []
        results.concat(more.select { |e| e[".tag"] == "file" }.map { |e| e["name"] })
      end

      results
    rescue ApiError => e
      return [] if e.message.include?("path/not_found")
      raise
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      path = dropbox_path(key, namespace)
      body = api_request("/files/get_temporary_link", path: path)
      body["link"]
    end

    def test_connection
      test_key = ".storage_test_#{SecureRandom.hex(4)}"
      path = dropbox_path(test_key, :files)

      # Upload test file
      content_request("/files/upload",
        body: "ok",
        api_arg: { path: path, mode: "overwrite", autorename: false })

      # Download it
      content_download("/files/download", api_arg: { path: path })

      # Delete it
      api_request("/files/delete_v2", path: path)

      { ok: true }
    rescue => e
      { ok: false, error: e.message }
    end

    class ApiError < StandardError; end

    private

    def dropbox_path(key, namespace)
      "#{ROOT_FOLDER}/#{namespace}/#{key}"
    end

    def ensure_folder_exists!(namespace)
      path = "#{ROOT_FOLDER}/#{namespace}"
      api_request("/files/create_folder_v2", path: path, autorename: false)
    rescue ApiError => e
      raise unless e.message.include?("path/conflict")
    end

    def api_request(endpoint, **params)
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "application/json")
        .post("#{BASE_URL}#{endpoint}", body: params.to_json)

      body = JSON.parse(response.body.to_s)

      if response.status >= 400
        error_summary = body["error_summary"] || body["error"] || "HTTP #{response.status}"
        raise ApiError, error_summary
      end

      body
    end

    def content_request(endpoint, body:, api_arg:)
      response = HTTP.timeout(60)
        .auth("Bearer #{@access_token}")
        .headers(
          "Content-Type" => "application/octet-stream",
          "Dropbox-API-Arg" => api_arg.to_json
        )
        .post("#{CONTENT_URL}#{endpoint}", body: body)

      if response.status >= 400
        parsed = JSON.parse(response.body.to_s) rescue {}
        error_summary = parsed["error_summary"] || "HTTP #{response.status}"
        raise ApiError, error_summary
      end

      JSON.parse(response.body.to_s) rescue {}
    end

    def content_download(endpoint, api_arg:)
      response = HTTP.timeout(60)
        .auth("Bearer #{@access_token}")
        .headers("Dropbox-API-Arg" => api_arg.to_json)
        .post("#{CONTENT_URL}#{endpoint}")

      if response.status >= 400
        parsed = JSON.parse(response.body.to_s) rescue {}
        error_summary = parsed["error_summary"] || "HTTP #{response.status}"
        raise ApiError, error_summary
      end

      response
    end
  end
end
