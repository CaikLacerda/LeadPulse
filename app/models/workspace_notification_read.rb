class WorkspaceNotificationRead < ApplicationRecord
  belongs_to :user

  validates :notification_key, presence: true, length: { maximum: 120 }, uniqueness: { scope: :user_id }
end
