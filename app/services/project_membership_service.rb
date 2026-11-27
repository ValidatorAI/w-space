class ProjectMembershipService
  class << self
    def add(project, user, actor: nil)
      return false if project.blank? || user.blank?
      return false if project.users.exists?(id: user.id)

      first_project_join = !user.project_users.exists?
      group_id = first_project_join ? SecureRandom.uuid : nil

      ActiveRecord::Base.transaction do
        project.project_users.create!(user: user)
        project.rooms.active.find_each do |room|
          room.memberships.grant_to(user)
        end
      end

      record_project_membership_event(project, "project_member_added", user, actor: actor, group_id: group_id)
      record_project_membership_event(project, "project_first_joined", user, actor: actor, group_id: group_id) if first_project_join
      true
    end

    def remove(project, user, actor: nil)
      return false if project.blank? || user.blank?
      return false if user == actor && project.users.exists?(id: user.id) && project.users.count == 1

      ActiveRecord::Base.transaction do
        project.project_users.where(user_id: user.id).delete_all
        project.rooms.find_each do |room|
          room.memberships.revoke_from(user)
        end
      end

      record_project_membership_event(project, "project_member_removed", user, actor: actor)
      true
    end

    private
      def record_project_membership_event(project, event_type, user, actor:, group_id: nil)
        OutputEvents::Recorder.record(
          event_type: event_type,
          event_id: project.id,
          group_id: group_id,
          actor: actor,
          target_type: "Project",
          data: { "member" => { "type" => "User", "id" => user.id } }
        )
      end
  end
end
