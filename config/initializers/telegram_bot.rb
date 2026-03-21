# frozen_string_literal: true

# Configure telegram-bot-ruby gem timeouts.
# Default: 20s. We set 30s to match TELEGRAM_TIMEOUT.
begin
  require "telegram/bot"

  telegram_timeout = ENV.fetch("TELEGRAM_TIMEOUT", "30").to_i

  Telegram::Bot.configure do |config|
    config.connection_timeout = telegram_timeout
    config.connection_open_timeout = [ telegram_timeout / 3, 10 ].max
  end
rescue LoadError
  # telegram-bot-ruby not available, skip configuration
end
