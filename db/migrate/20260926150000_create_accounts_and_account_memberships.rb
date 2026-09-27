# Fase 2 do tenancy por conta: a empresa (Account) passa a ser o tenant e os usuários
# participam dela por AccountMembership, onde fica o papel de cada um.
#
# As colunas de empresa, integração e política LGPD repetem nomes e defaults de `users`
# para que o backfill (fase 3) seja uma cópia direta. Nada em `users` é alterado aqui.
class CreateAccountsAndAccountMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false

      # Perfil da empresa
      t.string :validation_company_name
      t.string :validation_spoken_company_name
      t.string :validation_owner_name
      t.string :validation_owner_email
      t.text :validation_calling_profile

      # Conta na API de validação
      t.bigint :validation_account_id
      t.string :validation_external_account_id
      t.jsonb :validation_account_response, null: false, default: {}

      # Token da API de validação (texto já criptografado, mesmo formato de users.validation_api_token)
      t.text :validation_api_token
      t.string :validation_api_token_prefix
      t.datetime :validation_api_token_created_at

      # Twilio (o Auth Token não é armazenado localmente)
      t.string :validation_twilio_account_sid
      t.jsonb :validation_twilio_phone_numbers, null: false, default: []
      t.string :validation_twilio_webhook_base_url

      # OpenAI (a API Key não é armazenada localmente)
      t.string :validation_openai_realtime_model, null: false, default: "gpt-realtime-2.1-mini"
      t.string :validation_openai_realtime_voice, null: false, default: "cedar"
      t.decimal :validation_openai_realtime_output_speed, precision: 4, scale: 2
      t.text :validation_openai_style_instructions

      # Política LGPD da empresa
      t.string :lgpd_legal_basis, null: false, default: "legitimate_interest"
      t.string :lgpd_purpose, null: false, default: "qualificacao_de_fornecedores_por_chamada_automatizada"
      t.text :lgpd_notice_script
      t.integer :lgpd_evidence_retention_days, null: false, default: 180
      t.boolean :lgpd_recording_allowed, null: false, default: true
      t.boolean :lgpd_stop_automatic_calls_on_refusal, null: false, default: true
      t.string :lgpd_controller_name
      t.string :lgpd_controller_email

      t.timestamps
    end

    add_index :accounts, :validation_account_id, unique: true, where: "validation_account_id IS NOT NULL"
    add_index :accounts, :validation_external_account_id, unique: true, where: "validation_external_account_id IS NOT NULL"

    create_table :account_memberships do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end

    add_index :account_memberships, [ :account_id, :user_id ], unique: true
  end
end
