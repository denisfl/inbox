module StorageAdapter
  class OneDrive < Base
    GRAPH_URL = "https://graph.microsoft.com/v1.0".freeze
    ROOT_FOLDER = "Apps/Inbox".freeze

    def initialize(config: {})
      @access_token = config["access_token"] || config[:access_token]
    end

    def upload(file_path, key, namespace: :files)
      path = onedrive_path(key, namespace)
      body = File.binread(file_path)

      response = HTTP.timeout(60)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "application/octet-stream")
        .put("#{GRAPH_URL}/me/drive/root:/#{path}:/content", body: body)

      parse_response!(response)
      key
    end

    def download(key, namespace: :files)
      path = onedrive_path(key, namespace)

      # Get download URL (302 redirect) — use manual redirect handling
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .get("#{GRAPH_URL}/me/drive/root:/#{path}:/content")

      if response.status == 302
        download_url = response.headers["Location"]
        response = HTTP.timeout(60).get(download_url)
      end

      if response.status >= 400
        body = JSON.parse(response.body.to_s) rescue {}
        error_msg = body.dig("error", "message") || "HTTP #{response.status}"
        raise ApiError, error_msg
      end

      tempfile = Tempfile.new([ "onedrive_download", File.extname(key) ])
      tempfile.binmode
      tempfile.write(response.body.to_s)
      tempfile.rewind
      tempfile
    end

    def delete(key, namespace: :files)
      path = onedrive_path(key, namespace)

      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .delete("#{GRAPH_URL}/me/drive/root:/#{path}:")

      # 204 No Content = success, 404 = already gone
      return if [ 204, 404 ].include?(response.status.to_i)

      parse_response!(response)
    end

    def list(namespace: :files)
      path = "#{ROOT_FOLDER}/#{namespace}"
      results = []
      url = "#{GRAPH_URL}/me/drive/root:/#{path}:/children?$select=name,file"

      loop do
        response = HTTP.timeout(30)
          .auth("Bearer #{@access_token}")
          .get(url)

        body = parse_response!(response)
        items = body["value"] || []

        results.concat(
          items.select { |item| item.key?("file") }.map { |item| item["name"] }
        )

        url = body["@odata.nextLink"]
        break unless url
      end

      results
    rescue ApiError => e
      return [] if e.message.include?("itemNotFound")
      raise
    end

    def url(key, namespace: :files, expires_in: 1.hour)
      path = onedrive_path(key, namespace)

      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .post("#{GRAPH_URL}/me/drive/root:/#{path}:/createLink",
              json: { type: "view", scope: "anonymous" })

      body = parse_response!(response)
      body.dig("link", "webUrl")
    end

    def test_connection
      test_key = ".storage_test_#{SecureRandom.hex(4)}"
      path = onedrive_path(test_key, :files)

      # Upload test file
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .headers("Content-Type" => "application/octet-stream")
        .put("#{GRAPH_URL}/me/drive/root:/#{path}:/content", body: "ok")

      parse_response!(response)

      # Download it
      response = HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .get("#{GRAPH_URL}/me/drive/root:/#{path}:/content")

      if response.status == 302
        download_url = response.headers["Location"]
        response = HTTP.timeout(30).get(download_url)
      end

      # Delete it
      HTTP.timeout(30)
        .auth("Bearer #{@access_token}")
        .delete("#{GRAPH_URL}/me/drive/root:/#{path}:")

      { ok: true }
    rescue => e
      { ok: false, error: e.message }
    end

    class ApiError < StandardError; end

    private

    def onedrive_path(key, namespace)
      "#{ROOT_FOLDER}/#{namespace}/#{key}"
    end

    def parse_response!(response)
      return {} if response.status == 204

      body = JSON.parse(response.body.to_s)

      if response.status >= 400
        error_code = body.dig("error", "code")
        error_msg = body.dig("error", "message") || error_code || "HTTP #{response.status}"
        error_msg = "#{error_code}: #{error_msg}" if error_code && !error_msg.include?(error_code)
        raise ApiError, error_msg
      end

      body
    rescue JSON::ParserError
      raise ApiError, "Invalid response: HTTP #{response.status}"
    end
  end
end
