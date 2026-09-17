class Rooms::OpensController < RoomsController
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
    @room = Rooms::Open.new(name: DEFAULT_ROOM_NAME, project: @project, parent_id: @parent_room&.id)
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

    room = Rooms::Open.create_for(room_attributes, users: Current.user)
    group_id = SecureRandom.uuid

    broadcast_create_room(room)
    record_room_event("room_created", room, group_id: group_id)
    record_room_member_added(room, Current.user, group_id: group_id)
    redirect_to post_create_redirect_url(room)
  end

  def edit
    @users = users_scope_for_room_picker(@room.project)
    @agents = agents_scope_for_room_picker(@room.project)
  end

  def update
    @room.update! room_params

    broadcast_update_room
    record_room_event("room_updated", @room)
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

    # Allows us to edit a closed room and turn it into an open one on saving.
    def force_room_type
      @room = @room.becomes!(Rooms::Open)
    end

    def users_scope_for_room_picker(project)
      scope = project ? project.users : User.all
      scope.active.ordered
    end

    def agents_scope_for_room_picker(project)
      scope = project ? project.agents : Agent.all
      scope.active.ordered
    end

    def broadcast_create_room(room)
      broadcast_prepend_to :rooms, target: :shared_rooms, partial: "users/sidebars/rooms/shared", locals: { room: room }
    end

    def broadcast_update_room
      broadcast_replace_to :rooms, target: [ @room, :list ], partial: "users/sidebars/rooms/shared", locals: { room: @room }
    end

    def record_room_member_added(room, user, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: "room_member_added",
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "member" => { "type" => "User", "id" => user.id } }
      )
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
