class RoomsController < ApplicationController
  before_action :set_room, only: %i[ show destroy ]
  before_action :ensure_can_administer, only: %i[ destroy ]
  before_action :remember_last_room_visited, only: :show

  def index
    redirect_to room_url(Current.user.rooms.last)
  end

  def show
    @messages = find_messages
    prepare_room_shell_context
  end

  def destroy
    room_id = @room.id
    room_data = { "room_type" => @room.type, "project_id" => @room.project_id, "parent_id" => @room.parent_id }.compact
    @room.destroy

    broadcast_remove_room
    OutputEvents::Recorder.record(
      event_type: "room_deleted",
      event_id: room_id,
      actor: Current.user,
      target_type: "Room",
      data: room_data
    )
    redirect_to root_url
  end

  private
    def set_room
      if room = Current.user.rooms.find_by(id: params[:room_id] || params[:id])
        @room = room
      else
        redirect_to root_url, alert: "Room not found or inaccessible"
      end
    end

    def ensure_can_administer
      head :forbidden unless Current.user.can_administer?(@room)
    end

    def ensure_permission_to_create_rooms
      if Current.account.settings.restrict_room_creation_to_administrators? && !Current.user.administrator?
        head :forbidden
      end
    end

    def find_messages
      messages = Message.where(room: @room)
        .or(Message.where(room_id: @room.child_topics.select(:id)))
        .with_creator.with_attachment_details.with_boosts

      if show_first_message = messages.find_by(id: params[:message_id])
        @messages = messages.page_around(show_first_message)
      else
        @messages = messages.last_page
      end
    end

    def room_params
      params.require(:room).permit(:name)
    end

    def prepare_room_shell_context
      @room_project = @room.project || @room.parent&.project
      room_ids = [ @room.id ] + @room.child_topics.ids

      decision_requests_scope = ApprovalRequest.where(room_id: room_ids, request_type: "decision").recent
      @open_decision_requests = decision_requests_scope.where(status: :pending).limit(5)
      @recent_decision_requests = decision_requests_scope.limit(10)

      if @room_project
        @recent_decision_records = @room_project.adrs.active.ordered.limit(5)
        @artifact_assets = @room_project.external_assets.active.ordered.limit(6)
        @artifact_knowledge_items = @room_project.knowledge_items.active.ordered.limit(6)
        @room_outcome = @room_project.description.presence || @artifact_knowledge_items.first&.description
      else
        @recent_decision_records = []
        @artifact_assets = []
        @artifact_knowledge_items = []
        @room_outcome = nil
      end

      @room_participants = @room.memberships.includes(:participant).map(&:participant).compact
      @decision_items_count = @open_decision_requests.size + @recent_decision_records.size
      @artifact_items_count = @artifact_assets.size + @artifact_knowledge_items.size
    end

    def broadcast_remove_room
      broadcast_remove_to :rooms, target: [ @room, :list ]
    end

    def record_room_event(event_type, room, group_id: nil)
      OutputEvents::Recorder.record(
        event_type: event_type,
        event_id: room.id,
        group_id: group_id,
        actor: Current.user,
        target_type: "Room",
        data: { "room_type" => room.type, "project_id" => room.project_id, "parent_id" => room.parent_id }.compact
      )
    end
end
