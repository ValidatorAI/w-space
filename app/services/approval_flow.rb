class ApprovalFlow
  DECISIONS = {
    "approve" => :approve!,
    "confirm" => :confirm!,
    "deny" => :deny!,
    "cancel" => :cancel!
  }.freeze

  def self.decide!(approval_request, actor, decision:, note: nil, force: false)
    new(approval_request, actor).decide!(decision: decision, note: note, force: force)
  end

  def initialize(approval_request, actor)
    @approval_request = approval_request
    @actor = actor
  end

  def decide!(decision:, note: nil, force: false)
    normalized_decision = decision.to_s.downcase
    raise ArgumentError, "Unsupported decision: #{decision}. Allowed: #{DECISIONS.keys.join(", ")}" unless DECISIONS.key?(normalized_decision)

    if @approval_request.status != "pending"
      return @approval_request if force

      raise ArgumentError, "Approval request is already #{approval_status_label}. Use force: true to override."
    end

    ensure_human_actor!

    @approval_request.public_send(DECISIONS[normalized_decision], @actor, note: note)
    echo_message = SystemMessage.approval_decided(
      approval_request: @approval_request,
      actor: @actor,
      decision: normalized_decision,
      note: note
    )
    @approval_request.echo_message_id = echo_message&.id if @approval_request.respond_to?(:echo_message_id=)
    @approval_request
  end

  private

  def ensure_human_actor!
    return if @actor.is_a?(User) && !@actor.bot?

    raise ArgumentError, "Decision actor must be a human user"
  end

  def approval_status_label
    @approval_request.status.presence || "resolved"
  end
end
