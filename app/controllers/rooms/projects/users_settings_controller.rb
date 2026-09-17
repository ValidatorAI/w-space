module Rooms
  module Projects
    class UsersSettingsController < ApplicationController
      before_action :set_project
      before_action :set_project_room
      before_action :ensure_can_administer

      def show
        @users = @project.users.active.without_bots.ordered
        @bot_users = @project.users.active_bots.ordered
        @available_users = User.active.without_bots.where.not(id: @users.select(:id)).ordered
        @available_ai_teammate_options = available_bot_user_options

        render layout: false
      end

      def update
        refresh_project_settings = false

        case params[:intent]
        when "add_user"
          refresh_project_settings = add_user
        when "remove_user"
          refresh_project_settings = remove_user
        when "add_agent"
          refresh_project_settings = add_agent
        when "remove_agent"
          refresh_project_settings = remove_agent
        end

        redirect_to rooms_project_users_settings_path(@project, refresh_project_settings: refresh_project_settings)
      end

      private
        def set_project
          @project = Current.user.projects.find_by(id: params[:project_id])
          return if @project.present?

          redirect_to root_url, alert: "Project not found or inaccessible"
        end

        def set_project_room
          return if performed?

          @project_room = @project.ensure_project_room!
        end

        def ensure_can_administer
          return if performed?
          return if Current.user.can_administer?(@project_room)

          head :forbidden
        end

        def add_user
          user = User.active.without_bots.find_by(id: params[:participant_id])
          return false if user.blank?
          return false if @project.users.exists?(id: user.id)
          first_project_join = !user.project_users.exists?
          group_id = first_project_join ? SecureRandom.uuid : nil

          ActiveRecord::Base.transaction do
            @project.project_users.create!(user: user)
            @project.rooms.active.find_each do |room|
              room.memberships.grant_to(user)
            end
          end

          broadcast_project_room_added_for(user)
          record_project_membership_event("project_member_added", user, group_id: group_id)
          record_project_membership_event("project_first_joined", user, group_id: group_id) if first_project_join
          true
        end

        def remove_user
          user = @project.users.find_by(id: params[:participant_id])
          return false if user.blank?
          return false if user == Current.user

          ActiveRecord::Base.transaction do
            @project.project_users.where(user_id: user.id).delete_all
            @project.rooms.find_each do |room|
              room.memberships.revoke_from(user)
            end
          end

          broadcast_project_room_removed_for(user)
          record_project_membership_event("project_member_removed", user)
          true
        end

        def add_agent
          participant = find_available_bot_user(params[:participant_id])
          return false if participant.blank?
          added_to_project = !@project.users.exists?(id: participant.id)

          ActiveRecord::Base.transaction do
            if !@project.users.exists?(id: participant.id)
              @project.project_users.create!(user: participant)
            end

            @project.rooms.active.find_each do |room|
              room.memberships.grant_to(participant)
            end
          end

          record_project_membership_event("project_member_added", participant) if added_to_project
          true
        end

        def remove_agent
          participant = find_project_bot_user(params[:participant_id])
          return false if participant.blank?

          ActiveRecord::Base.transaction do
            @project.project_users.where(user_id: participant.id).delete_all

            @project.rooms.find_each do |room|
              room.memberships.revoke_from(participant)
            end
          end

          record_project_membership_event("project_member_removed", participant)
          true
        end

        def available_bot_users_scope
          User.active_bots.where(id: Current.account.allowed_bot_user_ids).ordered
        end

        def available_bot_user_options
          available_bot_users_scope.where.not(id: @bot_users.select(:id)).map do |bot_user|
            [ "#{bot_user.name} AI", "User:#{bot_user.id}" ]
          end
        end

        def find_available_bot_user(participant_key)
          key = participant_key.to_s
          return if key.blank?

          type, id = key.split(":", 2)
          return if id.blank?
          return unless type == "User"

          available_bot_users_scope.find_by(id: id)
        end

        def find_project_bot_user(participant_key)
          key = participant_key.to_s
          return if key.blank?

          type, id = key.split(":", 2)
          return if id.blank?
          return unless type == "User"

          @project.users.active_bots.find_by(id: id)
        end

        def broadcast_project_room_added_for(user)
          html = render_to_string(partial: "users/sidebars/rooms/shared", locals: { room: @project_room })

          broadcast_prepend_to user, :rooms, target: :shared_rooms, html: html
        end

        def broadcast_project_room_removed_for(user)
          broadcast_remove_to user, :rooms, target: [ @project_room, :list ]
        end

        def record_project_membership_event(event_type, user, group_id: nil)
          OutputEvents::Recorder.record(
            event_type: event_type,
            event_id: @project.id,
            group_id: group_id,
            actor: Current.user,
            target_type: "Project",
            data: { "member" => { "type" => "User", "id" => user.id } }
          )
        end
    end
  end
end
