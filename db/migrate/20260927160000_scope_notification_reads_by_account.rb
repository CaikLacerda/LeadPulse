# As chaves de notificação lida passam a levar a empresa ("account:ID:..."): quem participa
# de duas empresas não marca como lida a notificação da outra. Leituras antigas de quem tem
# uma só empresa recebem o prefixo dela, para não voltarem como não lidas.
class ScopeNotificationReadsByAccount < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE workspace_notification_reads r
      SET notification_key = 'account:' || m.account_id || ':' || r.notification_key
      FROM account_memberships m
      WHERE m.user_id = r.user_id
        AND r.notification_key NOT LIKE 'account:%'
        AND (SELECT COUNT(*) FROM account_memberships mm WHERE mm.user_id = r.user_id) = 1
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE workspace_notification_reads
      SET notification_key = regexp_replace(notification_key, '^account:[0-9]+:', '')
    SQL
  end
end
