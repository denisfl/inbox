# frozen_string_literal: true

# DomainEvents — publishes lifecycle events via ActiveSupport::Notifications.
#
# Include in any model to publish {model}.created, {model}.updated,
# {model}.deleted events after successful transaction commits.
#
# Uses after_save (not after_commit) for update events because ActionText
# body-only changes don't mark the parent record as "updated" for after_commit.
#
# Payload: { model_class:, model_id:, action:, changes:, timestamp: }
module DomainEvents
  extend ActiveSupport::Concern

  included do
    after_commit :publish_created_event, on: :create
    after_save :publish_updated_event_if_persisted
    after_commit :publish_deleted_event, on: :destroy
  end

  private

  def publish_created_event
    publish_domain_event("created")
  end

  def publish_updated_event_if_persisted
    return if previously_new_record?

    publish_domain_event("updated", changes: previous_changes)
  end

  def publish_deleted_event
    publish_domain_event("deleted")
  end

  def publish_domain_event(action, changes: nil)
    event_name = "#{self.class.name.underscore}.#{action}"
    payload = {
      model_class: self.class.name,
      model_id: id,
      action: action,
      changes: changes,
      timestamp: Time.current
    }
    ActiveSupport::Notifications.instrument(event_name, payload)
  end
end
