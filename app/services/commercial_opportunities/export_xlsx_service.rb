module CommercialOpportunities
  class ExportXlsxService
    CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

    def initialize(commercial_opportunity:)
      @commercial_opportunity = commercial_opportunity
    end

    def call
      rows = [
        [ "Fornecedor", "Telefone do retorno", "Preferência informada", "Data e horário normalizados", "Produto ou especificação", "Preço por unidade", "Preço por lote ou faixas", "Pedido mínimo", "Resultado", "Produto - resposta original", "Preço unitário - resposta original", "Lote - resposta original", "Pedido mínimo - resposta original" ],
        [
          @commercial_opportunity.supplier_name,
          @commercial_opportunity.callback_phone,
          @commercial_opportunity.callback_preferred_time,
          @commercial_opportunity.callback_schedule_label,
          @commercial_opportunity.display_product_specification,
          @commercial_opportunity.display_unit_price,
          @commercial_opportunity.display_lot_price_ranges,
          @commercial_opportunity.display_minimum_order,
          @commercial_opportunity.outcome,
          @commercial_opportunity.product_specification,
          @commercial_opportunity.unit_price,
          @commercial_opportunity.lot_price_ranges,
          @commercial_opportunity.minimum_order
        ]
      ]

      {
        filename: @commercial_opportunity.export_xlsx_filename,
        content: Spreadsheets::SimpleXlsxBuilder.new(sheet_name: "Coleta comercial", rows: rows).call,
        content_type: CONTENT_TYPE
      }
    end
  end
end
