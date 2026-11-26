module Simulations
  # Inicia uma execução: valida a escolha, chama a FastAPI e grava a projeção local.
  # Traduz os erros de negócio da API (409/422/429) em mensagens claras. No caso de já haver
  # uma execução ativa, devolve a execução local correspondente para redirecionar o usuário.
  class StartService
    Result = Struct.new(:success?, :simulation, :active_simulation, :error_message, keyword_init: true)

    def initialize(account:, user:, params:)
      @account = account
      @user = user
      @params = params.to_h.deep_symbolize_keys
    end

    def call
      target_type = @params[:target_type].presence || "system_workflow"
      workflow_key = @params[:workflow_key].to_s
      scenario_key = @params[:scenario_key].to_s
      mode = @params[:mode].presence || Simulation::MODE_AI_VS_AI

      if workflow_key.blank? || scenario_key.blank?
        return Result.new(success?: false, error_message: I18n.t("simulations.messages.incomplete_choice"))
      end

      # Só IA × IA pode iniciar nesta versão (os outros modos aparecem como "Em breve").
      unless mode == Simulation::MODE_AI_VS_AI
        return Result.new(success?: false, error_message: I18n.t("simulations.messages.mode_unavailable"))
      end

      run = ValidationApi::Simulations::CreateService.new.call(
        api_token: @account.validation_api_token_value,
        target_type: target_type,
        workflow_key: workflow_key,
        scenario_key: scenario_key,
        mode: mode,
        requested_by: "rails_user_#{@user.id}"
      )

      simulation = @account.simulations.create!(
        created_by: @user,
        remote_id: run.fetch("simulation_id"),
        mode: run["mode"].presence || mode,
        target_type: target_type,
        workflow_key: workflow_key,
        scenario_key: scenario_key,
        status: run["status"].presence || Simulation::STATUS_QUEUED
      )

      Result.new(success?: true, simulation: simulation)
    rescue ValidationApi::Error => e
      handle_api_error(e)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, error_message: e.record.errors.full_messages.to_sentence)
    end

    private

    def handle_api_error(error)
      code = error.details.is_a?(Hash) ? error.details["code"] : nil

      case code
      when "simulation_already_active"
        remote_id = error.details["simulation_id"]
        active = @account.simulations.find_by(remote_id: remote_id)
        Result.new(
          success?: false,
          active_simulation: active,
          error_message: I18n.t("simulations.messages.already_active")
        )
      when "simulation_not_configured"
        Result.new(success?: false, error_message: I18n.t("simulations.messages.not_configured"))
      when "simulation_capacity_reached"
        Result.new(success?: false, error_message: I18n.t("simulations.messages.capacity_reached"))
      else
        Result.new(success?: false, error_message: error.message)
      end
    end
  end
end
