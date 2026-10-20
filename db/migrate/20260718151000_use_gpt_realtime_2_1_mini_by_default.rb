class UseGptRealtime21MiniByDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users,
      :validation_openai_realtime_model,
      from: 'gpt-realtime-1.5',
      to: 'gpt-realtime-2.1-mini'

    execute <<~SQL.squish
      UPDATE users
      SET validation_openai_realtime_model = 'gpt-realtime-2.1-mini'
      WHERE validation_openai_realtime_model IS NULL
         OR validation_openai_realtime_model = ''
         OR validation_openai_realtime_model = 'gpt-realtime-1.5'
    SQL
  end

  def down
    change_column_default :users,
      :validation_openai_realtime_model,
      from: 'gpt-realtime-2.1-mini',
      to: 'gpt-realtime-1.5'
  end
end
