class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def mark_read
    notification_keys.each do |notification_key|
      current_user.workspace_notification_reads.find_or_create_by!(notification_key:) do |notification_read|
        notification_read.read_at = Time.current
      end
    end

    head :no_content
  end

  private

  def notification_keys
    Array(params[:notification_keys])
      .filter_map { |value| value.to_s.strip.presence }
      .select { |value| value.length <= 120 }
      .uniq
      .first(20)
  end
end
