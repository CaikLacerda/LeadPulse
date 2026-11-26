module Analytics
  # Lê os filtros da URL com lista permitida. Valor fora da lista volta ao padrão sem erro;
  # quando um ajuste muda o que a pessoa pediu, ele fica em #adjustments para a tela avisar.
  # Os períodos são dias inteiros em America/Sao_Paulo, com início e fim inclusivos.
  class Filters
    PERIOD_DAYS = { "7d" => 7, "30d" => 30, "90d" => 90 }.freeze
    PERIOD_TWELVE_MONTHS = "12m".freeze
    PERIOD_CUSTOM = "personalizado".freeze
    PERIODS = (PERIOD_DAYS.keys + [ PERIOD_TWELVE_MONTHS, PERIOD_CUSTOM ]).freeze
    DEFAULT_PERIOD = "30d".freeze
    MAX_CUSTOM_DAYS = 366

    COMPARE_PREVIOUS = "anterior".freeze
    COMPARE_PREVIOUS_YEAR = "ano_anterior".freeze
    COMPARE_NONE = "nenhum".freeze
    COMPARISONS = [ COMPARE_PREVIOUS, COMPARE_PREVIOUS_YEAR, COMPARE_NONE ].freeze

    GROUPING_DAY = "dia".freeze
    GROUPING_WEEK = "semana".freeze
    GROUPING_MONTH = "mes".freeze
    GROUPINGS = [ GROUPING_DAY, GROUPING_WEEK, GROUPING_MONTH ].freeze
    # Agrupamento padrão pelo tamanho da janela: até 31 dias por dia, até 92 por semana,
    # acima disso por mês. Evita dezenas de rótulos no eixo; o tooltip mostra o período exato.
    DAILY_LIMIT_DAYS = 31
    WEEKLY_LIMIT_DAYS = 92

    WORKFLOW_KINDS = SupplierImport::WORKFLOW_KIND_LABELS.keys.freeze
    SOURCES = SupplierImport::SOURCE_LABELS.keys.freeze
    STATUSES = [
      SupplierImport::LOCAL_STATUS_PENDING,
      SupplierImport::LOCAL_STATUS_PROCESSING,
      SupplierImport::LOCAL_STATUS_COMPLETED,
      SupplierImport::LOCAL_STATUS_ERROR
    ].freeze
    DIRECTIONS = %w[asc desc].freeze

    Window = Data.define(:first_day, :last_day) do
      def starts_at
        first_day.in_time_zone(Sql::TIME_ZONE)
      end

      # Fim exclusivo: início do dia seguinte ao último dia.
      def ends_at
        (last_day + 1).in_time_zone(Sql::TIME_ZONE)
      end

      def range
        starts_at...ends_at
      end

      def days
        (last_day - first_day).to_i + 1
      end

      def buckets(grouping)
        case grouping
        when GROUPING_WEEK then (first_day.beginning_of_week(:monday)..last_day).step(7).to_a
        when GROUPING_MONTH
          months = []
          month = first_day.beginning_of_month
          while month <= last_day
            months << month
            month = month.next_month
          end
          months
        else (first_day..last_day).to_a
        end
      end

      # Dias da janela cobertos por um período do gráfico (para o tooltip e o drill-down).
      def bucket_range(bucket, grouping)
        last = case grouping
        when GROUPING_WEEK then bucket + 6
        when GROUPING_MONTH then bucket.end_of_month
        else bucket
        end
        [ [ bucket, first_day ].max, [ last, last_day ].min ]
      end

      def label
        first = I18n.l(first_day, format: first_day.year == last_day.year ? "%-d %b" : "%-d %b %Y")
        "#{first} – #{I18n.l(last_day, format: '%-d %b %Y')}"
      end
    end

    attr_reader :period, :comparison, :workflow_kind, :source, :supplier_import_id, :status,
      :sort, :direction, :page, :adjustments

    def initialize(params, account:, today: Time.current.in_time_zone(Sql::TIME_ZONE).to_date)
      @params = params || {}
      @account = account
      @today = today
      @adjustments = []

      @period = allowed(:periodo, PERIODS, DEFAULT_PERIOD)
      @comparison = allowed(:comparar, COMPARISONS, COMPARE_PREVIOUS)
      @workflow_kind = allowed(:fluxo, WORKFLOW_KINDS, nil)
      @source = allowed(:origem, SOURCES, nil)
      @status = allowed(:status, STATUSES, nil)
      @supplier_import_id = read_supplier_import_id
      @requested_grouping = allowed(:agrupar, GROUPINGS, nil)
      @sort = @params[:ordem].to_s[/\A[a-z_]{1,40}\z/]
      @direction = allowed(:direcao, DIRECTIONS, nil)
      @page = [ @params[:page].to_s.to_i, 1 ].max
      @window = resolve_window
    end

    attr_reader :window

    def previous_window
      case comparison
      when COMPARE_PREVIOUS
        last_day = window.first_day - 1
        Window.new(first_day: last_day - (window.days - 1), last_day: last_day)
      when COMPARE_PREVIOUS_YEAR
        Window.new(first_day: window.first_day.prev_year, last_day: window.last_day.prev_year)
      end
    end

    def compare?
      previous_window.present?
    end

    def grouping
      return @requested_grouping if @requested_grouping
      return GROUPING_DAY if window.days <= DAILY_LIMIT_DAYS
      return GROUPING_WEEK if window.days <= WEEKLY_LIMIT_DAYS

      GROUPING_MONTH
    end

    def custom?
      period == PERIOD_CUSTOM
    end

    # Pedido de período personalizado, mesmo que as datas tenham sido recusadas.
    def custom_requested?
      @params[:periodo].to_s == PERIOD_CUSTOM
    end

    # Filtros não padrão, com os nomes da URL. Base das abas, links e exportações.
    def to_params(table: false)
      params = {
        periodo: (period unless period == DEFAULT_PERIOD),
        de: (window.first_day.iso8601 if custom?),
        ate: (window.last_day.iso8601 if custom?),
        comparar: (comparison unless comparison == COMPARE_PREVIOUS),
        fluxo: workflow_kind,
        origem: source,
        lote: supplier_import_id,
        status: status,
        agrupar: @requested_grouping
      }
      params.merge!(ordem: sort, direcao: direction, page: (page if page > 1)) if table
      params.compact
    end

    def cache_key(table: false)
      to_params(table: table).merge(hoje: @today.iso8601).sort.map { |key, value| "#{key}=#{value}" }.join("&")
    end

    def any_scope_filter?
      [ workflow_kind, source, supplier_import_id, status ].any?(&:present?)
    end

    private

    def allowed(key, values, default)
      value = @params[key].to_s
      values.include?(value) ? value : default
    end

    # Só aceita lote da própria conta; id de outra conta é ignorado como se não existisse.
    def read_supplier_import_id
      id = @params[:lote].to_s[/\A\d{1,18}\z/]&.to_i
      return if id.blank?

      @account.supplier_imports.where(id: id).exists? ? id : nil
    end

    def resolve_window
      case period
      when PERIOD_TWELVE_MONTHS
        Window.new(first_day: @today.prev_year + 1, last_day: @today)
      when PERIOD_CUSTOM
        custom_window || default_window
      else
        Window.new(first_day: @today - (PERIOD_DAYS.fetch(period) - 1), last_day: @today)
      end
    end

    def default_window
      @period = DEFAULT_PERIOD
      Window.new(first_day: @today - (PERIOD_DAYS.fetch(DEFAULT_PERIOD) - 1), last_day: @today)
    end

    def custom_window
      first_day = parse_date(@params[:de])
      last_day = parse_date(@params[:ate])
      if first_day.nil? || last_day.nil?
        @adjustments << :custom_period_incomplete
        return
      end

      first_day, last_day = last_day, first_day if first_day > last_day
      last_day = [ last_day, @today ].min
      first_day = [ first_day, last_day ].min
      if (last_day - first_day).to_i + 1 > MAX_CUSTOM_DAYS
        @adjustments << :custom_period_too_long
        return
      end

      Window.new(first_day: first_day, last_day: last_day)
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
  end
end
