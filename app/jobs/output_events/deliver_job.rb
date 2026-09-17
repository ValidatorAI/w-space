class OutputEvents::DeliverJob < ApplicationJob
  retry_on OutputEvents::DeliveryClient::TransientDeliveryError, wait: :polynomially_longer, attempts: 5

  def perform(output_event_id)
    event = OutputEvent.find_by(id: output_event_id)
    return if event.blank? || event.synced?

    unless ENV["OUTPUT_EVENTS_URL"].present?
      Rails.logger.warn("Output event #{event.id} was not delivered because OUTPUT_EVENTS_URL is not configured")
      return
    end

    OutputEvents::DeliveryClient.new.deliver(event)
    event.update!(synced: true)
  rescue OutputEvents::DeliveryClient::PermanentDeliveryError => error
    Rails.logger.error("Output event #{output_event_id} was not delivered: #{error.message}")
  end
end