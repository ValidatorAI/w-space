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
      attrs = user_attrs.to_h.with_indifferent_access
      permitted = attrs.slice("name", "display_name", "email_address", "password", "role").compact_blank
      return user if permitted.empty?

      if permitted.key?("role")
        role_name = permitted["role"].to_s.strip
        if role_name.blank?
          permitted.delete("role")
        elsif User.roles.key?(role_name)
          permitted["role"] = role_name
        else
          user.errors.add(:role, "is not a valid role")
          raise ValidationError.new(user)
        end
      end

      permitted = permitted.compact_blank
      return user if permitted.empty?

      if permitted.key?("password")
        user.password = permitted["password"]
        permitted.delete("password")
      end

      user.assign_attributes(permitted)
      user.save!
      user
    rescue ActiveRecord::RecordInvalid => e
      raise ValidationError.new(e.record)
    rescue ActiveRecord::RecordNotUnique
      raise DuplicateEmailError, "Email address is already in use"
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
