class Rooms::ClosedsController < RoomsController
  before_action :set_room, only: %i[ show edit update ]
  before_action :ensure_can_administer, only: %i[ update ]
  before_action :remember_last_room_visited, only: :show
  before_action :force_room_type, only: %i[ edit update ]
  before_action :ensure_permission_to_create_rooms, only: %i[ new create ]
  before_action :set_project_for_new_room, only: %i[ new create ]
  before_action :set_parent_room_for_new_room, only: %i[ new create ]

  DEFAULT_ROOM_NAME = "New room"

  def show
    redirect_to room_url(@room)
  end

  def new
    @room  = Rooms::Closed.new(name: DEFAULT_ROOM_NAME, project: @project, parent_id: @parent_room&.id)
    @users = users_scope_for_room_picker(@project)
    @agents = agents_scope_for_room_picker(@project)
  end

  def create
    room_attributes = room_params

    if @project
      room_attributes[:project_id] = @project.id
    end

    room_attributes[:parent_id] = if @parent_room
      @parent_room.id
    elsif @project
      @project.ensure_project_room!.id
    end

    if room_attributes[:project_id].blank? && @parent_room&.project_id.present?
      room_attributes[:project_id] = @parent_room.project_id
    end

    room = Rooms::Closed.create_for(room_attributes, users: grantees)
    group_id = SecureRandom.uuid

    broadcast_create_room(room)
    record_room_event("room_created", room, group_id: group_id)
    room.users.find_each { |user| record_room_member_added(room, user, group_id: group_id) }
    redirect_to post_create_redirect_url(room)
  end

  def edit
    selected_user_ids = @room.users.pluck(:id)
    @selected_users, @unselected_users = users_scope_for_room_picker(@room.project).partition { |user| selected_user_ids.include?(user.id) }

    selected_agent_ids = @room.agents.pluck(:id)
    @selected_agents, @unselected_agents = agents_scope_for_room_picker(@room.project).partition { |agent| selected_agent_ids.include?(agent.id) }
  end

  def update
    group_id = SecureRandom.uuid
    previously_private = @room.private?
    previous_user_ids = @room.user_ids
    @room.update! room_params
    @room.memberships.revise(granted: grantees, revoked: revokees)

    broadcast_update_room
    record_room_event("room_updated", @room, group_id: group_id)
    record_room_privacy_change(group_id: group_id) if previously_private != @room.private?
    record_membership_changes(previous_user_ids, group_id: group_id)
    redirect_to room_url(@room)
  end

  private
    def set_project_for_new_room
      project_id = params[:project_id] || params.dig(:room, :project_id)
      return if project_id.blank?

      @project = Current.user.projects.find_by(id: project_id)
      return if @project

      redirect_to root_url, alert: "Project not found or inaccessible"
    end

    def set_parent_room_for_new_room
      parent_room_id = params[:parent_room_id] || params.dig(:room, :parent_room_id)
      return if parent_room_id.blank?

      @parent_room = Current.user.rooms.find_by(id: parent_room_id)
      unless @parent_room
        redirect_to root_url, alert: "Parent room not found or inaccessible"
        return
      end

      return if @project.blank? || @parent_room.project_id == @project.id

      redirect_to root_url, alert: "Parent room does not belong to this project"
    end

    # Allows us to edit an open room and turn it into a closed one on saving.
    def force_room_type
      @room = @room.becomes!(Rooms::Closed)
    end

    def users_scope_for_room_picker(project)
      scope = project ? project.users : User.all
      scope.active.ordered
    end

    def agents_scope_for_room_picker(project)
      scope = project ? project.agents : Agent.all
      scope.active.ordered
    end

    def membership_scope_project
      @project || @room&.project
    end

    def scoped_grantee_ids
      @scoped_grantee_ids ||= begin
        scope = membership_scope_project ? membership_scope_project.users : User.all
        scope.active.where(id: grantee_ids).pluck(:id)
      end
    end

    def grantees
      User.where(id: scoped_grantee_ids)
    end

    def revokees
      @room.users.where.not(id: scoped_grantee_ids)
    end

    def grantee_ids
      params.fetch(:user_ids, [])
    end

    def broadcast_create_room(room)
      each_user_and_html_for(room) do |user, html|
        broadcast_prepend_to user, :rooms, target: :shared_rooms, html: html
      end
    end

    def broadcast_update_room
      each_user_and_html_for(@room) do |user, html|
        broadcast_replace_to user, :rooms, target: [ @room, :list ], html: html
      end
    end

    def record_room_member_added(room, user, group_id: nil)
      record_room_membership_event("room_member_added", room, user, group_id: group_id)
    end

    def record_membership_changes(previous_user_ids, group_id:)
      current_user_ids = @room.user_ids
      (current_user_ids - previous_user_ids).each { |user_id| record_room_membership_event("room_member_added", @room, User.find(user_id), group_id: group_id) }
      (previous_user_ids - current_user_ids).each { |user_id| record_room_membership_event("room_member_removed", @room, User.find(user_id), group_id: group_id) }
    end

    def record_room_membership_event(event_type, room, user, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "member" => { "type" => "User", "id" => user.id } }
      )
    end

    def record_room_privacy_change(group_id: nil)
      record_room_event("room_privacy_changed", @room, group_id: group_id)
    end

    def each_user_and_html_for(room)
      # Optimization to avoid rendering the same partial for every user
      html = render_to_string(partial: "users/sidebars/rooms/shared", locals: { room: room })

      room.users.each { |user| yield user, html }
    end

    def post_create_redirect_url(room)
      return room_url(room) unless created_from_project_settings?
      return room_url(room) unless @project

      edit_rooms_project_url(@project.id, by: "project")
    end

    def created_from_project_settings?
      ActiveModel::Type::Boolean.new.cast(params[:from_project_settings])
    end
end
