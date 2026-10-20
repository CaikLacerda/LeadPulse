class AddLgpdGovernanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: 'admin'
    add_column :users, :lgpd_legal_basis, :string, null: false, default: 'legitimate_interest'
    add_column :users, :lgpd_purpose, :string, null: false, default: 'qualificacao_de_fornecedores_por_chamada_automatizada'
    add_column :users, :lgpd_notice_script, :text
    add_column :users, :lgpd_evidence_retention_days, :integer, null: false, default: 180
    add_column :users, :lgpd_recording_allowed, :boolean, null: false, default: true
    add_column :users, :lgpd_controller_name, :string
    add_column :users, :lgpd_controller_email, :string
    add_column :users, :lgpd_stop_automatic_calls_on_refusal, :boolean, null: false, default: true
  end
end
