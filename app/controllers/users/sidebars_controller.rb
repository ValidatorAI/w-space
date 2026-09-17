class Users::SidebarsController < ApplicationController
  def show
    all_memberships     = Current.user.memberships.visible.with_ordered_room.merge(Room.active)
    project_memberships, non_project_memberships = all_memberships.partition { |membership| membership.room.project_room? }
    project_room_project_ids = {}

    project_memberships.each do |membership|
      project_room_project_ids[membership.room_id] = membership.room.project_id
    end

    non_project_memberships.each do |membership|
      next if membership.room.project_id.blank?

      project_room_project_ids[membership.room_id] = membership.room.project_id
    end

    loop do
      propagated = false

      non_project_memberships.each do |membership|
        next if project_room_project_ids.key?(membership.room_id)

        parent_project_id = project_room_project_ids[membership.room.parent_id]
        next if parent_project_id.blank?

        project_room_project_ids[membership.room_id] = parent_project_id
        propagated = true
      end

      break unless propagated
    end

    project_scoped_memberships = non_project_memberships.select { |membership| project_room_project_ids.key?(membership.room_id) }

    @direct_memberships = extract_direct_memberships(all_memberships)
    @other_memberships  = prioritize_company_memberships(
      non_project_memberships
        .without(@direct_memberships)
        .reject { |membership| room_without_parent_or_project?(membership.room) }
        .reject { |membership| project_room_project_ids.key?(membership.room_id) }
        .to_a
    )
    @project_memberships_by_room_id = project_memberships.index_by(&:room_id)
    @project_memberships_by_project_id = project_scoped_memberships.group_by do |membership|
      project_room_project_ids[membership.room_id]
    end
    @projects = Current.user.projects.includes(:rooms).sort_by { |project| project.display_name.to_s.downcase }

    @direct_contacts = User.active.where.not(id: Current.user.id).without_bots.ordered
    @direct_bot_contacts = User.active_bots.where.not(id: Current.user.id).ordered
  end

  private
    def extract_direct_memberships(all_memberships)
      all_memberships.select { |m| m.room.direct? }.sort_by { |m| m.room.updated_at }.reverse
    end

    def prioritize_company_memberships(memberships)
      home_memberships = memberships.select { |membership| company_home_room?(membership.room.name) }
      status_memberships = memberships.select { |membership| company_status_room?(membership.room.name) }
      remaining_memberships = memberships - home_memberships - status_memberships

      home_memberships + status_memberships + remaining_memberships
    end

    def company_home_room?(name)
      normalized_name = normalize_room_name(name)
      normalized_name == "home" || normalized_name == "company home"
    end

    def company_status_room?(name)
      normalize_room_name(name) == "company status"
    end

    def normalize_room_name(name)
      name.to_s
        .downcase
        .gsub(/[^a-z0-9 ]/, "")
        .squeeze(" ")
        .strip
    end

    def room_without_parent_or_project?(room)
      # a direct-message parent can never be displayed, so it doesn't count as a usable parent
      (room.parent_id.blank? || room.parent&.direct?) && room.project_id.blank?
    end
end
