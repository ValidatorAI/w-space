class ProjectAdminService
  class << self
    def create(attributes:, actor: nil)
      payload = attributes.to_h.deep_symbolize_keys
      path = payload[:path].presence || payload["path"].presence
      if path.present?
        existing = Project.find_by(path: path)
        return { project: existing, created: false } if existing
      end

      project = Project.new(payload)
      project.save!

      OutputEvents::Recorder.record(
        event_type: "project_created",
        event_id: project.id,
        group_id: SecureRandom.uuid,
        actor: actor,
        target_type: "Project",
        data: { "slug" => project.slug, "path" => project.path, "member_user_ids" => [] }
      )

      { project: project, created: true }
    end

    def update(project:, attributes:, actor: nil)
      project.assign_attributes(attributes.to_h.deep_symbolize_keys)
      project.save!

      if project.previous_changes.except("updated_at").any?
        OutputEvents::Recorder.record(
          event_type: "project_updated",
          event_id: project.id,
          group_id: SecureRandom.uuid,
          actor: actor,
          target_type: "Project",
          data: { "changed_fields" => project.previous_changes.except("updated_at").keys.map(&:to_s) }
        )
      end

      project
    end

    def destroy(project, actor: nil)
      raise ArgumentError, "open approvals exist: #{pending_approvals_count(project)}" if pending_approvals_count(project).positive?

      project.destroy!
      OutputEvents::Recorder.record(
        event_type: "project_deleted",
        event_id: project.id,
        actor: actor,
        target_type: "Project",
        data: {}
      )

      project
    end

    def pending_approvals_count(project)
      ApprovalRequest.joins(:room).where(rooms: { project_id: project.id }, status: :pending).count
    end
  end
end
