# frozen_string_literal: true

# Base class for domain event subscribers.
#
# Subclass and implement `call(event)`. Register via `subscribe(event_name)`.
# Errors are isolated — a failing subscriber is logged and doesn't block others.
class BaseSubscriber
  def self.subscribe(event_name)
    ActiveSupport::Notifications.subscribe(event_name) do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      begin
        new.call(event)
      rescue => e
        Rails.logger.error("[subscriber] #{name} failed on #{event_name}: #{e.message}")
      end
    end
  end

  def call(event)
    raise NotImplementedError, "#{self.class}#call must be implemented"
  end
end
