class Rooms::ProjectsController < RoomsController
  skip_before_action :set_room, only: %i[ edit update ]
  before_action :set_project_room, only: %i[ edit update ]
  before_action :set_project, only: %i[ edit update ]
  before_action :ensure_can_administer, only: %i[ update ]

  def edit
    @teammates = @room.users.active.ordered
    @channels = project_channels_scope
  end

  def update
    case params[:intent]
    when "archive_project"
      archive_project
    when "unarchive_project"
      unarchive_project
    when "delete_project"
      delete_project
    when "archive_channel"
      archive_channel
    when "unarchive_channel"
      unarchive_channel
    else
      update_project_details
    end
  end

  private
    def set_project_room
      room = if params[:by] == "project"
        project = Current.user.projects.find_by(id: params[:id])
        project&.ensure_project_room!
      else
        Room.find_by(id: params[:id], type: "Rooms::Project")
      end

      unless room && Current.user.projects.exists?(id: room.project_id)
        redirect_to root_url, alert: "Project not found or inaccessible"
        return
      end

      @room = room
    end

    def set_project
      @project = @room.project
      return if @project.present?

      redirect_to root_url, alert: "Project not found or inaccessible"
    end

    def update_project_details
      group_id = SecureRandom.uuid
      ActiveRecord::Base.transaction do
        @project.update!(project_params)
        @room.update!(
          name: @project.display_name,
          description: @project.description,
          private: @project.private
        )
      end

      broadcast_update_room
      OutputEvents::Recorder.record(
        event_type: "project_updated",
        event_id: @project.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Project",
        data: { "changed_fields" => @project.previous_changes.except("updated_at").keys }
      )
      record_room_privacy_change(group_id: group_id) if @room.previous_changes.key?("private")
      redirect_to edit_rooms_project_url(@project.id, by: "project"), notice: "Project settings updated"
    end

    def archive_project
      group_id = SecureRandom.uuid
      rooms = @project.rooms.active.to_a
      rooms.each(&:archive!)
      rooms.each { |room| broadcast_remove_to :rooms, target: [ room, :list ] }
      record_project_event("project_archived", group_id: group_id)
      rooms.each { |room| record_room_lifecycle_event("room_archived", room, group_id: group_id) }

      redirect_to edit_rooms_project_url(@project.id, by: "project"), notice: "Project archived"
    end

    def unarchive_project
      group_id = SecureRandom.uuid
      rooms = @project.rooms.archived.to_a
      rooms.each(&:unarchive!)

      broadcast_update_room
      record_project_event("project_unarchived", group_id: group_id)
      rooms.each { |room| record_room_lifecycle_event("room_unarchived", room, group_id: group_id) }
      redirect_to edit_rooms_project_url(@project.id, by: "project"), notice: "Project unarchived"
    end

    def delete_project
      rooms = @project.rooms.to_a
      project_id = @project.id
      @project.destroy!
      rooms.each { |room| broadcast_remove_to :rooms, target: [ room, :list ] }
      OutputEvents::Recorder.record(
        event_type: "project_deleted",
        event_id: project_id,
        actor: Current.user,
        target_type: "Project",
        data: {}
      )

      redirect_to root_url, notice: "Project deleted"
    end

    def archive_channel
      channel = project_channels_scope.find_by(id: params[:channel_id])
      unless channel
        redirect_to edit_rooms_project_url(@project.id, by: "project"), alert: "Channel not found"
        return
      end

      channel.archive!
      broadcast_remove_to :rooms, target: [ channel, :list ]
      record_room_lifecycle_event("room_archived", channel)
      redirect_to edit_rooms_project_url(@project.id, by: "project"), notice: "Channel archived"
    end

    def unarchive_channel
      channel = project_channels_scope.find_by(id: params[:channel_id])
      unless channel
        redirect_to edit_rooms_project_url(@project.id, by: "project"), alert: "Channel not found"
        return
      end

      channel.unarchive!
      record_room_lifecycle_event("room_unarchived", channel)
      redirect_to edit_rooms_project_url(@project.id, by: "project"), notice: "Channel unarchived"
    end

    def project_channels_scope
      @project.rooms.where(parent_id: @room.id).ordered
    end

    def project_params
      params.fetch(:project, {}).permit(:name, :description, :private, :budget_total, :budget_spent, :roadmap)
    end

    def broadcast_update_room
      broadcast_replace_to :rooms, target: [ @room, :list ], partial: "users/sidebars/rooms/shared", locals: { room: @room }
    end

    def record_project_event(event_type, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: @project.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Project",
        data: {}
      )
    end

    def record_room_lifecycle_event(event_type, room, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "room_type" => room.type, "project_id" => room.project_id }
      )
    end

    def record_room_privacy_change(group_id: nil)
      OutputEvents::Recorder.record(
        event_type: "room_privacy_changed",
        event_id: @room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "private" => @room.private? }
      )
    end
end
