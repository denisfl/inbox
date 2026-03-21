# frozen_string_literal: true

# Unified HTTP client wrapper for external service calls.
# Provides configurable timeouts, retry with exponential backoff,
# and structured tagged logging for all outgoing HTTP requests.
#
# Usage:
#   client = ExternalServiceClient.new(:transcriber, timeout: 600)
#   response = client.post("http://transcriber:5000/transcribe", form: { audio: file })
#
#   client = ExternalServiceClient.new(:telegram, timeout: 30)
#   response = client.get("https://api.telegram.org/file/bot.../path")
#
class ExternalServiceClient
  # Errors that indicate transient failures worth retrying
  TRANSIENT_ERRORS = [
    HTTP::TimeoutError,
    HTTP::ConnectionError,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
    Errno::ENETUNREACH,
    SocketError
  ].freeze

  # Default timeouts per service (seconds), overridable via ENV
  DEFAULT_TIMEOUTS = {
    transcriber: 600,
    telegram: 30,
    google_calendar: 15,
    health_check: 5
  }.freeze

  # Retry configuration
  MAX_ATTEMPTS = 3
  BACKOFF_BASE = 1 # seconds — delays: 1s, 4s, 9s (n^2)

  attr_reader :service_name, :timeout

  def initialize(service_name, timeout: nil)
    @service_name = service_name.to_sym
    @timeout = timeout || timeout_for(service_name)
  end

  # Perform a GET request with retry and logging.
  def get(url, **options)
    request(:get, url, **options)
  end

  # Perform a POST request with retry and logging.
  def post(url, **options)
    request(:post, url, **options)
  end

  private

  def request(method, url, retries: MAX_ATTEMPTS, **options)
    attempt = 0

    begin
      attempt += 1
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = http_client.send(method, url, **options)
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2)

      if response.status.success?
        log_success(method, url, response.status.code, elapsed)
        response
      elsif response.status.code == 429
        handle_rate_limit(method, url, response, attempt, retries)
      elsif response.status.client_error?
        # 4xx (except 429) — permanent failure, do not retry
        log_failure(method, url, "HTTP #{response.status.code}", elapsed, attempt, retries)
        response
      else
        # 5xx — transient, retry
        raise TransientHttpError.new("HTTP #{response.status.code}", response)
      end
    rescue *TRANSIENT_ERRORS, TransientHttpError => e
      elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).round(2) rescue 0
      log_failure(method, url, "#{e.class}: #{e.message}", elapsed, attempt, retries)

      if attempt < retries
        delay = BACKOFF_BASE * (attempt**2)
        sleep(delay)
        retry
      end

      raise
    end
  end

  def handle_rate_limit(method, url, response, attempt, retries)
    retry_after = response.headers["Retry-After"]&.to_i || 60
    log_rate_limit(method, url, retry_after, attempt, retries)

    if attempt < retries
      sleep(retry_after)
      request(method, url, retries: retries - attempt)
    else
      response
    end
  end

  def http_client
    HTTP.timeout(timeout)
  end

  def timeout_for(service_name)
    env_key = "#{service_name.to_s.upcase}_TIMEOUT"
    env_value = ENV[env_key]
    return env_value.to_i if env_value.present?

    DEFAULT_TIMEOUTS.fetch(service_name.to_sym, 30)
  end

  # ── Logging ────────────────────────────────────────────────────────────────

  def log_success(method, url, status, elapsed)
    Rails.logger.tagged("[#{service_name}]") do
      Rails.logger.debug("#{method.upcase} #{url} → #{status} (#{elapsed}s)")
    end
  end

  def log_failure(method, url, error, elapsed, attempt, max_attempts)
    Rails.logger.tagged("[#{service_name}]") do
      Rails.logger.error("#{method.upcase} #{url} FAILED: #{error} (#{elapsed}s) [attempt #{attempt}/#{max_attempts}]")
    end
  end

  def log_rate_limit(method, url, retry_after, attempt, max_attempts)
    Rails.logger.tagged("[#{service_name}]") do
      Rails.logger.warn("#{method.upcase} #{url} → 429 Rate Limited, waiting #{retry_after}s [attempt #{attempt}/#{max_attempts}]")
    end
  end

  # Wrapper error for 5xx responses to trigger retry logic
  class TransientHttpError < StandardError
    attr_reader :response

    def initialize(message, response = nil)
      @response = response
      super(message)
    end
  end
end
