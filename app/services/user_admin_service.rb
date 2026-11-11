class UserAdminService
  class ValidationError < StandardError
    attr_reader :record

    def initialize(record)
      @record = record
    end
  end

  class DuplicateEmailError < StandardError
  end

  class << self
    def create(user_attrs, actor: nil)
      attributes = user_attrs.to_h.with_indifferent_access
      user = User.new(attributes)
      user.display_name = user.name if user.display_name.blank?

      user.save!
      OutputEvents::Recorder.record(
        event_type: "user_activated",
        event_id: user.id,
        actor: actor,
        target_type: "User",
        data: { "created" => true }
      )
      user
    rescue ActiveRecord::RecordInvalid => e
      raise ValidationError.new(e.record)
    rescue ActiveRecord::RecordNotUnique
      raise DuplicateEmailError, "Email address is already in use"
    end

    def update(user, user_attrs)
      role_name = user_attrs.to_h.with_indifferent_access[:role].presence_in(%w[ member administrator ]) || "member"
      user.update!(role: role_name)
      user
    end

    def activate(user, actor: nil)
      user.update!(status: :active)
      OutputEvents::Recorder.record(
        event_type: "user_activated",
        event_id: user.id,
        actor: actor,
        target_type: "User",
        data: {}
      )
      user
    end

    def deactivate(user, actor: nil)
      user.deactivate
      OutputEvents::Recorder.record(
        event_type: "user_deactivated",
        event_id: user.id,
        actor: actor,
        target_type: "User",
        data: {}
      )
      user
    end
  end
end
