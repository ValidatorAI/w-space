class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request

  def show
    respond_to do |format|
      format.html { redirect_to room_path(@approval_request.room) if @approval_request.room }
      format.json { render json: @approval_request }
    end
  end

  def approve
    @approval_request = ApprovalFlow.decide!(@approval_request, Current.user, decision: :approve, note: params[:note])

    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_back fallback_location: root_path, notice: "Approval request approved." }
      format.json { render json: { status: @approval_request.status, id: @approval_request.id, echo_message_id: @approval_request.echo_message_id } }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back fallback_location: root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def confirm
    @approval_request = ApprovalFlow.decide!(@approval_request, Current.user, decision: :confirm, note: params[:note])

    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_back fallback_location: root_path, notice: "Approval request confirmed." }
      format.json { render json: { status: @approval_request.status, id: @approval_request.id, echo_message_id: @approval_request.echo_message_id } }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back fallback_location: root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def deny
    @approval_request = ApprovalFlow.decide!(@approval_request, Current.user, decision: :deny, note: params[:note])

    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_back fallback_location: root_path, notice: "Approval request denied." }
      format.json { render json: { status: @approval_request.status, id: @approval_request.id, echo_message_id: @approval_request.echo_message_id } }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back fallback_location: root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  def cancel
    @approval_request = ApprovalFlow.decide!(@approval_request, Current.user, decision: :cancel, note: params[:note])

    respond_to do |format|
      format.turbo_stream { render :update }
      format.html { redirect_back fallback_location: root_path, notice: "Approval request canceled." }
      format.json { render json: { status: @approval_request.status, id: @approval_request.id, echo_message_id: @approval_request.echo_message_id } }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.turbo_stream { head :unprocessable_entity }
      format.html { redirect_back fallback_location: root_path, alert: e.message }
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private
    def set_approval_request
      @approval_request = ApprovalRequest.find(params[:id])
    end
end
