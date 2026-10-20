require "test_helper"

# Guarda do modelo de tenancy: a empresa (account_id) é a dona de todo dado de negócio e
# user_id só existe onde representa a própria pessoa (vínculo e leitura de notificação).
class TenancySchemaTest < ActiveSupport::TestCase
  BUSINESS_TABLES = %w[
    supplier_imports supplier_discovery_searches commercial_opportunities audit_reviews
    privacy_requests privacy_audit_events third_party_operators account_invitations analytics_api_tokens
  ].freeze
  PERSONAL_USER_TABLES = %w[account_memberships workspace_notification_reads mobile_sessions].freeze

  # Únicas tabelas sem empresa. Uma tabela nova fora desta lista precisa de account_id.
  TABLES_WITHOUT_ACCOUNT = {
    "accounts" => "é o próprio tenant",
    "users" => "pessoa; participa das empresas por account_memberships",
    "workspace_notification_reads" => "leitura pessoal; a chave da notificação leva a empresa",
    "plans" => "sem uso no código (candidata a remoção)",
    "suppliers" => "sem uso no código (candidata a remoção)",
    "supplier_import_versions" => "sem uso no código (candidata a remoção)",
    "schema_migrations" => "Rails",
    "ar_internal_metadata" => "Rails"
  }.freeze

  test "every table outside the explicit exceptions belongs to an account" do
    connection = ActiveRecord::Base.connection
    without_account = (connection.tables - TABLES_WITHOUT_ACCOUNT.keys).reject do |table|
      column = connection.columns(table).find { |candidate| candidate.name == "account_id" }
      column && !column.null
    end

    assert_empty without_account, "Tabelas sem account_id obrigatório: #{without_account.join(', ')}"
  end

  test "only personal tables have user_id" do
    connection = ActiveRecord::Base.connection
    with_user_id = connection.tables.select { |table| connection.column_exists?(table, :user_id) }

    assert_equal PERSONAL_USER_TABLES.sort, with_user_id.sort
  end

  test "every business table requires an account with a foreign key" do
    connection = ActiveRecord::Base.connection

    BUSINESS_TABLES.each do |table|
      column = connection.columns(table).find { |candidate| candidate.name == "account_id" }
      assert column, "#{table} sem account_id"
      assert_not column.null, "#{table}.account_id aceita nulo"
      assert connection.foreign_keys(table).any? { |key| key.column == "account_id" && key.to_table == "accounts" }, "#{table} sem FK para accounts"
      assert connection.index_exists?(table, :account_id) || connection.indexes(table).any? { |index| index.columns.first == "account_id" }, "#{table} sem índice por account_id"
    end
  end

  test "authorship columns are optional and survive user deletion" do
    connection = ActiveRecord::Base.connection
    authorship = connection.tables.flat_map do |table|
      connection.foreign_keys(table).select { |key| key.to_table == "users" && key.column.end_with?("_by_id") }
    end

    assert authorship.any?
    authorship.each do |key|
      assert_equal :nullify, key.on_delete, "#{key.from_table}.#{key.column} deveria anular ao excluir o usuário"
    end
  end

  test "no business query filters by user_id" do
    offenders = Dir[Rails.root.join("app/**/*.{rb,erb}")].select do |path|
      next false if path.include?("account_membership") || path.include?("notification")

      source = File.read(path).gsub(/membership\.user_id/, "")
      source.match?(/where\([^)]*user_id|user_id:\s*current_user|\.user_id\b/)
    end

    assert_empty offenders.map { |path| path.delete_prefix(Rails.root.to_s + "/") }
  end

  test "roles and statuses are also constrained in the database" do
    connection = ActiveRecord::Base.connection
    expected = {
      "account_memberships" => %w[account_memberships_role_check account_memberships_status_check],
      "account_invitations" => %w[account_invitations_role_check],
      "supplier_imports" => %w[supplier_imports_status_check supplier_imports_workflow_kind_check supplier_imports_source_check],
      "commercial_opportunities" => %w[commercial_opportunities_status_check],
      "privacy_requests" => %w[privacy_requests_status_check]
    }

    expected.each do |table, names|
      assert_empty names - connection.check_constraints(table).map(&:name), table
    end
  end
end
