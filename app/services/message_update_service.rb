class MessageUpdateService
  class << self
    def call(message, body: nil, attachment: nil, actor: nil)
      raise ArgumentError, "Message not found" if message.blank?

      authorize!(message, actor || message.creator)
      apply_updates!(message, body: body, attachment: attachment)
      message
    end

    private

    def authorize!(message, actor)
      if message.system?
        raise ArgumentError, "system messages are admin-only" unless actor.present? && actor.respond_to?(:administrator?) && actor.administrator?
        return
      end

      raise ArgumentError, "not author" if actor.blank?
      raise ArgumentError, "not author" unless actor == message.creator
    end

    def apply_updates!(message, body:, attachment:)
      if body.present?
        message.update!(body: body)
      end

      if attachment.present?
        message.attachment.attach(attachment)
        message.process_attachment
      end
    end
  end
end
