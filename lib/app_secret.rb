# frozen_string_literal: true

# Reads sensitive values from Docker secrets (/run/secrets/<name>) first,
# falling back to ENV. Works in both Docker (with mounted secrets) and
# local development (with .env / shell exports).
#
# Usage:
#   AppSecret.fetch("TELEGRAM_BOT_TOKEN")         # raises KeyError if missing
#   AppSecret.fetch("API_TOKEN", "default_value")  # returns default if missing
#   AppSecret["TELEGRAM_BOT_TOKEN"]                # returns nil if missing
#
module AppSecret
  SECRETS_DIR = "/run/secrets"

  # Fetch a secret value. Checks Docker secrets first, then ENV.
  # Raises KeyError if not found and no default/block given.
  def self.fetch(name, *args, &block)
    value = read_secret(name)
    return value if value

    ENV.fetch(name, *args, &block)
  end

  # Read a secret value, returning nil if not found.
  def self.[](name)
    read_secret(name) || ENV[name]
  end

  private_class_method def self.read_secret(name)
    path = File.join(SECRETS_DIR, name.to_s.downcase)
    return unless File.readable?(path)

    File.read(path).strip.presence
  end
end
