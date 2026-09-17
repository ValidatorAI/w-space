class SystemMessage
  SYSTEM_USER_EMAIL = "system@bonfire.local"

  class << self
    # Post to a specific room, and optionally mirror to the meta events room
    def post(room:, type:, data: {}, mirror_to_meta: true)
      return unless room

      message = Message.create!(
        room: room,
        creator: system_user,
        body: render_body(type, data),
        system: true,
        system_type: type.to_s
      ).tap(&:broadcast_create)

      # Also post to meta events room unless we're already posting there
      if mirror_to_meta && !room.is_a?(Rooms::Meta)
        post_to_meta(type: type, data: data.merge(room_name: room.name))
      end

      message
    end

    # Post directly to meta room (for global events)
    def post_to_meta(type:, data: {})
      meta_room = Rooms::Meta.first
      return unless meta_room

      Message.create!(
        room: meta_room,
        creator: system_user,
        body: render_body(type, data),
        system: true,
        system_type: type.to_s
      ).tap(&:broadcast_create)
    end

    # Agent events
    def agent_joined(room:, agent:)
      post(room: room, type: :agent_join, data: {
        agent_name: agent.name,
        program: agent.program,
        task: agent.task_description || "No task specified"
      })
    end

    def agent_left(room:, agent:)
      post(room: room, type: :agent_leave, data: { agent_name: agent.name })
    end

    def agent_reconnected(room:, agent:)
      post(room: room, type: :agent_reconnect, data: {
        agent_name: agent.name,
        program: agent.program
      })
    end

    # Reservation events (don't mirror to meta - too noisy)
    def reservation_acquired(room:, agent:, patterns:)
      post(room: room, type: :reservation_acquired, mirror_to_meta: false, data: {
        agent_name: agent.name,
        patterns: Array(patterns).join(", ")
      })
    end

    def reservation_released(room:, agent:, patterns:)
      post(room: room, type: :reservation_released, mirror_to_meta: false, data: {
        agent_name: agent.name,
        patterns: Array(patterns).join(", ")
      })
    end

    def reservation_conflict(room:, requester:, holder:, patterns:)
      post(room: room, type: :reservation_conflict, mirror_to_meta: false, data: {
        requester_name: requester.name,
        holder_name: holder.name,
        patterns: Array(patterns).join(", ")
      })
    end

    def reservation_expired(room:, agent:, patterns:)
      post(room: room, type: :reservation_expired, mirror_to_meta: false, data: {
        agent_name: agent.name,
        patterns: Array(patterns).join(", ")
      })
    end

    # Room/Project events (posted only to meta room)
    def room_created(room:, creator:)
      post_to_meta(type: :room_created, data: {
        room_name: room.name,
        room_type: room.class.name.demodulize,
        creator_name: creator&.name || "System"
      })
    end

    def project_created(project:)
      post_to_meta(type: :project_created, data: {
        project_name: project.slug,
        project_path: project.path
      })
    end

    private

    def system_user
      @system_user ||= User.find_or_create_by!(email_address: SYSTEM_USER_EMAIL) do |u|
        u.name = "W space System"
        u.role = :bot
        u.password = SecureRandom.hex(32)
      end
    end

    def render_body(type, data)
      I18n.t("system_messages.#{type}", **data.symbolize_keys, default: type.to_s.humanize)
    end
  end
end
