class ProjectAllHandsMeeting < ApplicationRecord
  belongs_to :project

  has_many :takeaways, class_name: "ProjectAllHandsTakeaway", dependent: :destroy
  has_many :action_items, class_name: "ProjectAllHandsActionItem", dependent: :destroy
  has_many :decisions, class_name: "ProjectAllHandsDecision", dependent: :destroy

  validates :title, presence: true
  validates :bbb_meeting_id, presence: true, uniqueness: true
  validates :moderator_pw, presence: true
  validates :attendee_pw, presence: true

  before_validation :set_defaults, on: :create

  scope :ordered, -> { order(position: :asc, created_at: :desc) }

  def pending_action_items_count
    action_items.pending.count
  end

  def create_in_big_blue_button!
    self.bbb_meeting_id ||= "project-all-hands-#{project_id}-#{SecureRandom.uuid}"
    self.moderator_pw ||= SecureRandom.alphanumeric(16)
    self.attendee_pw ||= SecureRandom.alphanumeric(16)

    response = BigBlueButtonService.create_meeting(
      name: title,
      meeting_id: bbb_meeting_id,
      moderator_pw: moderator_pw,
      attendee_pw: attendee_pw
    )

    self.join_url = extract_join_url(response)
    self.running = true
    self.started_at ||= Time.current
    self.last_seen_at = Time.current
    save!
    self
  end

  def moderator_join_url
    response = BigBlueButtonService.join_moderator(
      meeting_id: bbb_meeting_id,
      full_name: Current.user&.effective_display_name || "Moderator",
      user_id: "moderator-#{id}",
      password: moderator_pw
    )

    fresh_join_url = extract_join_url(response)
    self.join_url = fresh_join_url if fresh_join_url.present?
    self.running = true
    self.last_seen_at = Time.current
    save! if persisted?
    fresh_join_url
  end

  def member_join_url(full_name = "Guest")
    response = BigBlueButtonService.join_member(
      meeting_id: bbb_meeting_id,
      full_name: full_name,
      user_id: "attendee-#{id}",
      password: attendee_pw
    )

    extract_join_url(response)
  end

  def self.current_running_for(project)
    active_scope = project.project_all_hands_meetings.where(running: true).order(created_at: :desc)

    response = BigBlueButtonService.get_all_meetings
    meeting_ids = extract_remote_meeting_ids(response)

    return active_scope if meeting_ids.blank?

    active_scope.where(bbb_meeting_id: meeting_ids).or(active_scope)
  rescue StandardError, WebMock::NetConnectNotAllowedError => e
    Rails.logger.warn("Unable to load BBB meetings for project #{project.id}: #{e.class}: #{e.message}")
    active_scope
  end

  private
    def set_defaults
      self.bbb_meeting_id ||= "project-all-hands-#{project_id || "unknown"}-#{SecureRandom.uuid}"
      self.moderator_pw ||= SecureRandom.alphanumeric(16)
      self.attendee_pw ||= SecureRandom.alphanumeric(16)
      self.position ||= 0
    end

    def extract_join_url(response)
      return nil if response.blank?

      response[:url].presence ||
        response["url"].presence ||
        response[:location].presence ||
        response["location"].presence ||
        response.dig(:joinURL).presence ||
        response.dig(:join_url).presence
    end

    def self.extract_remote_meeting_ids(response)
      return [] if response.blank?

      raw_meetings = Array(response.dig(:meetings, :meeting)).flatten
      raw_meetings.filter_map do |meeting|
        value = meeting.is_a?(Hash) ? (meeting[:meetingID] || meeting["meetingID"]) : nil
        value.presence
      end
    end
end
