require "test_helper"

class Simulations::StartServiceTest < ActiveSupport::TestCase
  include SimulationApiStub

  setup do
    @user = create_member!(name: "Starter", email: "starter@example.com")
    @account = account_of(@user)
    @account.update!(validation_api_token: "lp_test_token")
  end

  def start(params)
    Simulations::StartService.new(account: @account, user: @user, params: params).call
  end

  test "persists a local projection on success" do
    run = { "simulation_id" => "sim_1", "status" => "queued", "mode" => "ai_vs_ai" }

    result = stub_simulation_api(create: run) do
      start(mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel")
    end

    assert result.success?
    assert_equal "sim_1", result.simulation.remote_id
    assert_equal "supplier_validation", result.simulation.workflow_key
    assert_equal @user, result.simulation.created_by
    assert_equal "queued", result.simulation.status
  end

  test "rejects an unavailable mode without calling the API" do
    result = start(mode: "phone_call", workflow_key: "supplier_validation", scenario_key: "favoravel")

    assert_not result.success?
    assert_equal I18n.t("simulations.messages.mode_unavailable"), result.error_message
    assert_equal 0, @account.simulations.count
  end

  test "rejects an incomplete choice" do
    result = start(mode: "ai_vs_ai", workflow_key: "", scenario_key: "")

    assert_not result.success?
    assert_equal I18n.t("simulations.messages.incomplete_choice"), result.error_message
  end

  test "maps already active and recovers the local simulation" do
    active = @account.simulations.create!(remote_id: "sim_active", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "running")
    error = ValidationApi::Error.new("ativa", status_code: 409, details: { "code" => "simulation_already_active", "simulation_id" => "sim_active" })

    result = stub_simulation_api(create: error) do
      start(mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel")
    end

    assert_not result.success?
    assert_equal active, result.active_simulation
    assert_equal I18n.t("simulations.messages.already_active"), result.error_message
  end

  test "maps not configured and capacity errors" do
    not_configured = ValidationApi::Error.new("sem openai", status_code: 409, details: { "code" => "simulation_not_configured" })
    capacity = ValidationApi::Error.new("cheio", status_code: 429, details: { "code" => "simulation_capacity_reached" })

    configured_result = stub_simulation_api(create: not_configured) do
      start(mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel")
    end
    assert_equal I18n.t("simulations.messages.not_configured"), configured_result.error_message

    capacity_result = stub_simulation_api(create: capacity) do
      start(mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel")
    end
    assert_equal I18n.t("simulations.messages.capacity_reached"), capacity_result.error_message
  end
end
