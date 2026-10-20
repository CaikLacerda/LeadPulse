class ThirdPartyOperatorsController < ApplicationController
  before_action :authenticate_user!
  require_permission :can_manage_lgpd?, message: "Seu perfil não possui permissão para gerenciar LGPD."
  before_action :set_operator, only: [ :update, :destroy ]

  def index
    ThirdPartyOperators::EnsureDefaultsService.new(account: current_account, user: current_user).call
    @operators = current_account.third_party_operators.order(active: :desc, name: :asc)
    @operator = current_account.third_party_operators.new(active: true)
  end

  def create
    @operator = current_account.third_party_operators.new(operator_params.merge(created_by: current_user))

    if @operator.save
      PrivacyAudit::Logger.log!(
        account: current_account,
        user: current_user,
        action: "third_party_operator_created",
        resource: @operator,
        metadata: { name: @operator.name, service_type: @operator.service_type }
      )
      redirect_to third_party_operators_path, notice: "Operador/terceiro registrado."
    else
      @operators = current_account.third_party_operators.order(active: :desc, name: :asc)
      flash.now[:alert] = @operator.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def update
    if @operator.update(operator_params)
      PrivacyAudit::Logger.log!(
        account: current_account,
        user: current_user,
        action: "third_party_operator_updated",
        resource: @operator,
        metadata: { name: @operator.name, service_type: @operator.service_type, active: @operator.active? }
      )
      redirect_to third_party_operators_path, notice: "Operador/terceiro atualizado."
    else
      @operators = current_account.third_party_operators.order(active: :desc, name: :asc)
      flash.now[:alert] = @operator.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @operator.update!(active: false)
    PrivacyAudit::Logger.log!(
      account: current_account,
      user: current_user,
      action: "third_party_operator_disabled",
      resource: @operator,
      metadata: { name: @operator.name, service_type: @operator.service_type }
    )
    redirect_to third_party_operators_path, notice: "Operador/terceiro desativado."
  end

  private

  def set_operator
    @operator = current_account.third_party_operators.find(params[:id])
  end

  def operator_params
    params.require(:third_party_operator).permit(
      :name,
      :service_type,
      :data_shared,
      :purpose,
      :country,
      :contract_reference,
      :technical_owner,
      :active
    )
  end
end
