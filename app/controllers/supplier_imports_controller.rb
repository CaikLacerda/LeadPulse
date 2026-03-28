# app/controllers/supplier_imports_controller.rb
class SupplierImportsController < ApplicationController
  before_action :authenticate_user!

  def index
    @imports = current_user.supplier_imports.order(created_at: :desc)

    # Filtro por status
    if params[:status].present? && params[:status] != "todos"
      @imports = @imports.where(status: params[:status])
    end

    # Filtro por período
    if params[:periodo].present?
      case params[:periodo]
      when "7d"  then @imports = @imports.where("created_at >= ?", 7.days.ago)
      when "30d" then @imports = @imports.where("created_at >= ?", 30.days.ago)
      when "1y"  then @imports = @imports.where("created_at >= ?", 1.year.ago)
      end
    end

    # Busca por ID
    if params[:q].present?
      @imports = @imports.where("id::text ILIKE ?", "%#{params[:q]}%")
    end
  end

  def export
    # Renderiza o formulário de exportação
  end

  def import
    # Renderiza o formulário de importação
  end

  def create_import
    @import = current_user.supplier_imports.new
    @import.xlsx_data = params[:file].read if params[:file].present?
    @import.status = "pendente"
    @import.total_rows = 0
    @import.valid_rows = 0
    @import.invalid_rows = 0

    if @import.save
      redirect_to supplier_imports_path, notice: "Arquivo importado com sucesso!"
    else
      render :import, status: :unprocessable_entity
    end
  end
end