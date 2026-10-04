require "test_helper"

class SimulationsControllerTest < ActionDispatch::IntegrationTest
  include SimulationApiStub

  setup do
    @password = "Password123!"
    @user = create_member!(name: "Sim Test", email: "sim@example.com", password: @password)
    account_of(@user).update!(validation_api_token: "lp_test_token")
  end

  def sign_in!(user = @user)
    post user_session_url, params: { user: { email: user.email, password: @password } }
  end

  CATALOG = {
    "modes" => [
      { "key" => "ai_vs_ai", "label" => "IA × IA", "description" => "Automática.", "available" => true },
      { "key" => "browser_voice", "label" => "Navegador", "description" => "Microfone.", "available" => false },
      { "key" => "phone_call", "label" => "Chamada real", "description" => "Twilio.", "available" => false }
    ],
    "targets" => [
      {
        "target_type" => "system_workflow",
        "key" => "supplier_validation",
        "label" => "Validação de fornecedor",
        "description" => "Confirma telefone, segmento e retorno.",
        "scenarios" => [
          { "key" => "favoravel", "label" => "Favorável", "description" => "Tudo certo.", "expected_outcome" => "confirmed" },
          { "key" => "parcial", "label" => "Parcial", "description" => "Parte.", "expected_outcome" => "inconclusive" },
          { "key" => "dificil", "label" => "Difícil", "description" => "Resistente.", "expected_outcome" => "rejected" }
        ],
        "output_schema" => []
      }
    ]
  }.freeze

  # --- guards -------------------------------------------------------------
  test "redirects guests to sign in" do
    get simulations_url
    assert_redirected_to new_user_session_path
  end

  test "new redirects when the API token is missing" do
    account_of(@user).update!(validation_api_token: nil)
    sign_in!
    get new_simulation_url
    assert_redirected_to simulations_path
    assert_equal I18n.t("simulations.messages.missing_token"), flash[:alert]
  end

  # --- index --------------------------------------------------------------
  test "index lists only the current account simulations" do
    mine = account_of(@user).simulations.create!(remote_id: "sim_mine", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "completed", accuracy: 1.0)
    other_account = Account.create!(name: "Outra")
    other_account.simulations.create!(remote_id: "sim_other", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "completed")

    sign_in!
    get simulations_url

    assert_response :success
    assert_select "h1", text: /Ambiente de Simulação/
    assert_match mine.display_code, response.body
    assert_no_match(/sim_other/, response.body)
  end

  # --- new (catalog) ------------------------------------------------------
  test "new renders modes from the catalog, marking unavailable ones" do
    sign_in!
    stub_simulation_api(catalog: CATALOG) do
      get new_simulation_url
    end

    assert_response :success
    assert_select ".sim-mode", count: 3
    assert_select ".sim-mode--available", count: 1
    assert_select ".sim-mode__tag", text: /Em breve/, minimum: 2
  end

  # --- create -------------------------------------------------------------
  test "create starts an ai_vs_ai simulation and redirects to it" do
    run = { "simulation_id" => "sim_new_1", "status" => "queued", "mode" => "ai_vs_ai" }
    sign_in!

    stub_simulation_api(create: run) do
      assert_difference -> { account_of(@user).simulations.count }, 1 do
        post simulations_url, params: { simulation: { mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", target_type: "system_workflow" } }
      end
    end

    simulation = account_of(@user).simulations.order(:id).last
    assert_equal "sim_new_1", simulation.remote_id
    assert_redirected_to simulation_path(simulation)
  end

  test "create blocks viewers" do
    change_role!(@user, "viewer")
    sign_in!

    assert_no_difference -> { Simulation.count } do
      post simulations_url, params: { simulation: { mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel" } }
    end
    assert_redirected_to simulations_path
    assert_equal I18n.t("simulations.messages.forbidden"), flash[:alert]
  end

  test "create surfaces a 409 already active and points to the running simulation" do
    active = account_of(@user).simulations.create!(remote_id: "sim_active", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "running")
    error = ValidationApi::Error.new("já ativa", status_code: 409, details: { "code" => "simulation_already_active", "simulation_id" => "sim_active" })
    sign_in!

    stub_simulation_api(create: error) do
      assert_no_difference -> { Simulation.count } do
        post simulations_url, params: { simulation: { mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel" } }
      end
    end

    assert_redirected_to simulation_path(active)
    assert_equal I18n.t("simulations.messages.already_active"), flash[:alert]
  end

  test "create surfaces a 422 invalid choice" do
    error = ValidationApi::Error.new("cenário inválido", status_code: 422, details: { "detail" => "cenário inválido" })
    sign_in!

    stub_simulation_api(create: error) do
      post simulations_url, params: { simulation: { mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel" } }
    end

    assert_redirected_to new_simulation_path
    assert_equal "cenário inválido", flash[:alert]
  end

  # --- show + report ------------------------------------------------------
  test "show renders the live stage while running" do
    simulation = account_of(@user).simulations.create!(remote_id: "sim_live", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "running")
    sign_in!

    stub_simulation_api(show: { "status" => "running", "terminal" => false }) do
      get simulation_url(simulation)
    end

    assert_response :success
    assert_select ".sim-arena", count: 1
    assert_select "[data-controller~=simulation-live]", count: 1
  end

  test "show renders the final report when terminal" do
    simulation = account_of(@user).simulations.create!(remote_id: "sim_done", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "completed")
    run = {
      "status" => "completed", "terminal" => true, "call_result" => "confirmed", "accuracy" => 1.0, "raw_value_accuracy" => 1.0,
      "duration_ms" => 92_000, "turn_count" => 8,
      "evaluation" => { "expected_outcome" => "confirmed", "fields" => [ { "name" => "phone_belongs_to_company", "label" => "Telefone pertence à empresa", "expected" => true, "collected" => true, "status" => "correct_verified" } ] },
      "transcript" => { "agent_view" => [ { "role" => "assistant", "transcript" => "Olá, confirma o telefone?" } ], "counterpart_view" => [] }
    }
    sign_in!

    stub_simulation_api(show: run) do
      get simulation_url(simulation)
    end

    assert_response :success
    assert_select ".sim-report__table", count: 1
    assert_select ".sim-field-status--correct_verified"
    assert_match "Telefone pertence à empresa", response.body
  end

  # --- events (polling proxy) --------------------------------------------
  test "events proxies the timeline and reconciles the local status" do
    simulation = account_of(@user).simulations.create!(remote_id: "sim_poll", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "queued")
    payload = {
      "status" => "running", "terminal" => false, "next_after" => 3,
      "events" => [ { "seq" => 2, "at_ms" => 100, "type" => "participant_state", "payload" => { "participant" => "agent", "state" => "speaking" } } ]
    }
    sign_in!

    stub_simulation_api(events: payload) do
      get events_simulation_url(simulation, after: 1)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "running", body["status"]
    assert_equal 3, body["next_after"]
    assert_equal 1, body["events"].size
    assert_equal "running", simulation.reload.status
  end

  test "events includes the report html when terminal with no pending events" do
    simulation = account_of(@user).simulations.create!(remote_id: "sim_poll_done", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "running")
    events_payload = { "status" => "completed", "terminal" => true, "next_after" => 9, "events" => [] }
    run = {
      "status" => "completed", "terminal" => true, "call_result" => "confirmed", "accuracy" => 1.0,
      "evaluation" => { "expected_outcome" => "confirmed", "fields" => [] }, "transcript" => { "agent_view" => [], "counterpart_view" => [] }
    }
    sign_in!

    stub_simulation_api(events: events_payload, show: run) do
      get events_simulation_url(simulation, after: 5)
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert body["terminal"]
    assert_includes body["report_html"], "sim-report__inner"
    assert_equal "completed", simulation.reload.status
  end

  # --- cancel -------------------------------------------------------------
  test "cancel requests cancellation and reconciles status" do
    simulation = account_of(@user).simulations.create!(remote_id: "sim_cancel", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "running")
    sign_in!

    stub_simulation_api(cancel: { "status" => "cancelled", "terminal" => true }) do
      post cancel_simulation_url(simulation)
    end

    assert_redirected_to simulation_path(simulation)
    assert_equal "cancelled", simulation.reload.status
  end

  # --- account isolation --------------------------------------------------
  test "cannot open a simulation from another account" do
    other = Account.create!(name: "Outra").simulations.create!(remote_id: "sim_x", mode: "ai_vs_ai", workflow_key: "supplier_validation", scenario_key: "favoravel", status: "completed")
    sign_in!

    # O escopo por current_account faz o find falhar; a aplicação responde 404 para id de outra empresa.
    get simulation_url(other)
    assert_response :not_found
  end
end
