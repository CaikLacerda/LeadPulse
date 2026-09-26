class CreateWorkspaceNotificationReads < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_notification_reads do |t|
      t.references :user, null: false, foreign_key: true
      t.string :notification_key, null: false, limit: 120
      t.datetime :read_at, null: false

      t.timestamps
    end

    add_index :workspace_notification_reads, [ :user_id, :notification_key ], unique: true
  end
end
