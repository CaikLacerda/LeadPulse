# Troca da empresa atual, para quem participa de mais de uma. Só aceita empresa em que o
# usuário tem vínculo ativo; qualquer outro id é tratado como inexistente.
class AccountSelectionsController < ApplicationController
  before_action :authenticate_user!

  def create
    raise ActiveRecord::RecordNotFound unless select_current_account!(params[:account_id])

    redirect_to root_path, notice: "Você está trabalhando em #{current_account.validation_company_name_value}."
  end
end
