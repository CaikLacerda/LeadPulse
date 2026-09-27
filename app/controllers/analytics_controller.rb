# Indicadores agregados da conta atual. Todos os papéis veem os agregados; os dados vêm
# sempre de Analytics::Scope, a partir de current_account.
class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_report

  def overview
    @page = @report.overview
  end

  private

  def load_report
    @filters = Analytics::Filters.new(params, account: current_account)
    @scope = Analytics::Scope.new(account: current_account, filters: @filters)
    @report = Analytics::Report.new(scope: @scope)
  end
end
