# Ambiente de Simulação (Passo 3, lado Rails). O Rails é o intermediário: o navegador nunca
# fala com a FastAPI. A API executa a conversa e é a fonte da verdade; aqui guardamos uma
# projeção local para o histórico e repassamos catálogo, criação, polling e cancelamento.
class SimulationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_api_token, only: [ :new, :create ]
  before_action :set_simulation, only: [ :show, :events, :cancel ]

  PER_PAGE = 10

  def index
    simulations = current_account.simulations.recent_first
    @simulations = simulations.limit(PER_PAGE)
    @active_simulation = current_account.simulations.active.recent_first.first
  end

  def new
    catalog = fetch_catalog
    return redirect_to simulations_path, alert: catalog.error_message unless catalog.success?

    @catalog = catalog.data
  end

  def create
    unless current_membership.can_start_validation?
      return redirect_to simulations_path, alert: t("simulations.messages.forbidden")
    end

    result = ::Simulations::StartService.new(
      account: current_account,
      user: current_user,
      params: simulation_params
    ).call

    if result.success?
      redirect_to simulation_path(result.simulation)
    elsif result.active_simulation
      redirect_to simulation_path(result.active_simulation), alert: result.error_message
    else
      redirect_to new_simulation_path, alert: result.error_message
    end
  end

  def show
    # O estado completo vem da API; a projeção local é reconciliada no caminho de polling e aqui.
    run = fetch_run
    if run.success?
      @simulation.apply_remote_snapshot!(run.data)
      @run = run.data
    else
      @run = nil
      @run_error = run.error_message
    end
  end

  # Proxy de polling: o Stimulus chama este endpoint, que repassa para a API usando o token da
  # empresa. Devolve os eventos novos e, quando a execução termina, o resultado final.
  def events
    after = params[:after].to_i
    result = ValidationApi::Simulations::EventsService.new.call(
      api_token: current_account.validation_api_token_value,
      remote_id: @simulation.remote_id,
      after: after,
      limit: 200
    )

    reconcile_status(result["status"])

    payload = {
      status: result["status"],
      terminal: result["terminal"],
      next_after: result["next_after"],
      events: result["events"]
    }

    if result["terminal"] && Array(result["events"]).empty?
      run = fetch_run
      if run.success?
        @simulation.apply_remote_snapshot!(run.data)
        payload[:report_html] = render_to_string(partial: "simulations/report", locals: { run: run.data, simulation: @simulation }, formats: [ :html ])
      end
    end

    render json: payload
  rescue ValidationApi::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def cancel
    result = ValidationApi::Simulations::CancelService.new.call(
      api_token: current_account.validation_api_token_value,
      remote_id: @simulation.remote_id
    )
    reconcile_status(result["status"])
    redirect_to simulation_path(@simulation), notice: t("simulations.messages.cancel_requested")
  rescue ValidationApi::Error => e
    redirect_to simulation_path(@simulation), alert: e.message
  end

  private

  def set_simulation
    @simulation = current_account.simulations.find(params[:id])
  end

  def require_api_token
    return if current_account.validation_api_token_configured?

    redirect_to simulations_path, alert: t("simulations.messages.missing_token")
  end

  def simulation_params
    params.fetch(:simulation, ActionController::Parameters.new).permit(
      :mode, :workflow_key, :scenario_key, :target_type
    )
  end

  def fetch_catalog
    data = ValidationApi::Simulations::CatalogService.new.call(
      api_token: current_account.validation_api_token_value
    )
    ServiceResult.new(success?: true, data: data)
  rescue ValidationApi::Error => e
    ServiceResult.new(success?: false, error_message: e.message)
  end

  def fetch_run
    data = ValidationApi::Simulations::ShowService.new.call(
      api_token: current_account.validation_api_token_value,
      remote_id: @simulation.remote_id
    )
    ServiceResult.new(success?: true, data: data)
  rescue ValidationApi::Error => e
    ServiceResult.new(success?: false, error_message: e.message)
  end

  def reconcile_status(remote_status)
    return if remote_status.blank?
    return unless Simulation::STATUSES.include?(remote_status)
    return if @simulation.status == remote_status

    @simulation.update(status: remote_status)
  end

  ServiceResult = Struct.new(:success?, :data, :error_message, keyword_init: true)
end
