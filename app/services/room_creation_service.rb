class RoomCreationService
  class << self
    def create(name:, description: nil, private: false, project_id: nil, parent_room_id: nil, user_ids: [], actor: nil)
      project = project_id.present? ? Project.find_by(id: project_id) || Project.find_by(slug: project_id) : nil
      parent = parent_room_id.present? ? Room.find_by(id: parent_room_id) : nil

      if project.present? && parent.present? && parent.project_id != project.id
        raise ActiveRecord::RecordInvalid.new(Rooms::Open.new, "parent room does not belong to this project")
      end

      if project.blank? && parent.present? && parent.project_id.present?
        project = parent.project
      end

      room_attributes = {
        type: "Rooms::Open",
        name: name,
        description: description,
        private: ActiveModel::Type::Boolean.new.cast(private),
        project_id: project&.id,
        parent_id: parent&.id
      }

      room_attributes[:parent_id] = project.ensure_project_room!.id if room_attributes[:project_id].present? && room_attributes[:parent_id].blank?
      room_attributes[:project_id] = parent.project_id if room_attributes[:project_id].blank? && parent&.project_id.present?

      actor_member = actor.is_a?(User) ? actor : nil
      resolved_users = [actor_member].compact + Array(user_ids).filter_map { |user_id| User.find_by(id: user_id) }
      resolved_users.uniq! { |user| [user.class.name, user.id] }

      room = Room.transaction do
        Rooms::Open.create_for(room_attributes, users: resolved_users, creator: actor_member || actor)
      end

      group_id = SecureRandom.uuid
      record_room_event(room, "room_created", actor: actor_member || actor, group_id: group_id)
      room.users.find_each do |user|
        record_room_member_added(room, user, actor: actor_member || actor, group_id: group_id)
      end

      room
    end

    def ensure_project_room(project, actor: nil)
      project = project.is_a?(Project) ? project : Project.find_by(id: project) || Project.find_by(slug: project)
      raise ActiveRecord::RecordInvalid.new(Project.new, "Project not found") if project.nil?

      room = project.project_room
      created = room.nil?
      room ||= project.ensure_project_room!
      [room, created]
    end

    private
      def record_room_event(room, event_type, actor:, group_id: nil)
        OutputEvents::Recorder.record(
          event_type: event_type,
          event_id: room.id,
          group_id: group_id,
          actor: actor,
          target_type: "Room",
          data: { "room_type" => room.type, "project_id" => room.project_id, "parent_id" => room.parent_id }.compact
        )
      end

      def record_room_member_added(room, user, actor:, group_id: nil)
        OutputEvents::Recorder.record(
          event_type: "room_member_added",
          event_id: room.id,
          group_id: group_id,
          actor: actor,
          target_type: "Room",
          data: { "member" => { "type" => "User", "id" => user.id } }
        )
      end
  end
end
