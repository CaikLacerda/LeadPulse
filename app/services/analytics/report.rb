module Analytics
  # Monta as páginas do Analytics a partir de Analytics::Scope: roda as queries para a janela
  # atual e para a de comparação e calcula as variações no backend.
  #
  # Cada seção é isolada: falha de banco (inclusive o timeout de 5 s) vira uma seção com erro,
  # registrada no log com conta e filtros, e o restante da página continua. Cada seção tem cache
  # próprio, com chave por conta, filtros e versão das fontes que ela lê.
  class Report
    # Mude a versão sempre que o formato dos dados de uma seção mudar: o cache guarda esse formato.
    CACHE_VERSION = "v4".freeze
    CACHE_TTL = 10.minutes
    STATEMENT_TIMEOUT = "5s".freeze

    BATCH_SOURCES = [ SupplierImport ].freeze
    QUALIFICATION_SOURCES = [ SupplierImport, CommercialOpportunity ].freeze
    SEARCH_SOURCES = [ SupplierDiscoverySearch, SupplierImport ].freeze
    REVIEW_SOURCES = [ AuditReview, SupplierImport ].freeze

    Section = Data.define(:name, :data, :error) do
      def failed?
        error
      end
    end

    Page = Data.define(:name, :sections) do
      def [](section_name)
        sections.fetch(section_name)
      end
    end

    attr_reader :filters

    def initialize(scope:, cache: Rails.cache, logger: Rails.logger)
      @scope = scope
      @filters = scope.filters
      @cache = cache
      @logger = logger
      @source_versions = {}
    end

    def overview
      build_page(
        :overview,
        summary: [ BATCH_SOURCES, -> { overview_summary } ],
        evolution: [ BATCH_SOURCES, -> { evolution } ],
        top_batches: [ BATCH_SOURCES, -> { BatchesQuery.new(@scope.validated_batches(window)).top } ]
      )
    end

    def calls
      build_page(
        :calls,
        summary: [ BATCH_SOURCES, -> { calls_summary } ],
        daily: [ BATCH_SOURCES, -> { { grouping: filters.grouping, rows: attempts(window).daily(filters.grouping) } } ],
        heatmap: [ BATCH_SOURCES, -> { attempts(window).weekday_hours } ]
      )
    end

    def qualification
      build_page(
        :qualification,
        summary: [ QUALIFICATION_SOURCES, -> { qualification_summary } ],
        searches: [ SEARCH_SOURCES, -> { searches_summary } ],
        reviews: [ REVIEW_SOURCES, -> { reviews_summary } ]
      )
    end

    def batches
      build_page(
        :batches,
        summary: [ BATCH_SOURCES, -> { batches_summary } ],
        table: [
          BATCH_SOURCES,
          -> { BatchesQuery.new(@scope.created_batches(window)).page(sort: filters.sort, direction: filters.direction, page: filters.page) },
          { table: true }
        ]
      )
    end

    private

    def window
      filters.window
    end

    def previous_window
      filters.previous_window
    end

    def build_page(name, definitions)
      sections = definitions.to_h do |section_name, (sources, block, options)|
        [ section_name, section(name, section_name, sources, **(options || {}), &block) ]
      end
      Page.new(name: name, sections: sections)
    end

    def section(page, name, sources, table: false)
      key = [ "analytics", CACHE_VERSION, @scope.account.id, page, name, filters.cache_key(table: table), source_version(sources) ]
      data = @cache.fetch(key, expires_in: CACHE_TTL) { with_statement_timeout { yield } }
      Section.new(name: name, data: data, error: false)
    rescue StandardError => error
      raise if Rails.env.local? && !error.is_a?(ActiveRecord::ActiveRecordError)

      @logger.error(
        "[analytics] seção #{page}.#{name} falhou account_id=#{@scope.account.id} " \
          "filtros=#{filters.cache_key(table: table).inspect} erro=#{error.class}: #{error.message.to_s.truncate(300)}"
      )
      Section.new(name: name, data: nil, error: true)
    end

    def with_statement_timeout
      SupplierImport.transaction(requires_new: true) do
        SupplierImport.connection.execute("SET LOCAL statement_timeout = '#{STATEMENT_TIMEOUT}'")
        yield
      end
    end

    def source_version(sources)
      @source_versions[sources] ||= @scope.source_version(sources)
    end

    # Roda o bloco para a janela atual e, se houver comparação, para a anterior.
    def both_windows
      [ yield(window), (yield(previous_window) if filters.compare?) ]
    end

    def compare(current, previous)
      Comparison.new(current: yield(current), previous: (yield(previous) if previous))
    end

    def records(target_window)
      RecordsQuery.new(@scope.validated_batches(target_window))
    end

    # Uma query por janela, reaproveitada entre as seções da mesma requisição.
    def attempts(target_window)
      @attempts ||= {}
      @attempts[target_window] ||= AttemptsQuery.new(@scope.attempt_batches(target_window), target_window, grouping: filters.grouping)
    end

    def overview_summary
      current, previous = both_windows { |target| records(target).summary }
      calls_current, calls_previous = both_windows { |target| attempts(target).summary }

      {
        metrics: {
          records: compare(current, previous) { |summary| Metric.count(summary[:records]) },
          validation_rate: compare(current, previous) { |summary| Metric.rate(summary[:validated], summary[:validated] + summary[:not_validated]) },
          confirmation_rate: compare(current, previous) { |summary| Metric.rate(summary[:results]["confirmed"], summary[:terminal]) },
          answer_rate: compare(calls_current, calls_previous) { |summary| Metric.rate(summary[:answered], summary[:answer_base]) },
          median_duration: compare(calls_current, calls_previous) { |summary| Metric.duration(summary[:median_duration], summary[:with_duration]) },
          batches: compare(current, previous) { |summary| Metric.count(summary[:batches]) }
        },
        duration_coverage: Metric.rate(calls_current[:with_duration], calls_current[:answered]),
        privacy_refusals: Metric.rate(current[:privacy_refusals], current[:records]),
        awaiting_sync: current[:awaiting_sync],
        processing: current[:processing],
        results: current[:results],
        funnel: [
          [ :sent, current[:records] ],
          [ :called, current[:called] ],
          [ :answered, current[:answered] ],
          [ :confirmed, current[:results]["confirmed"] ]
        ]
      }
    end

    # Série atual e, alinhado por posição (dia 1 com dia 1), o total da janela de comparação.
    def evolution
      grouping = filters.grouping
      current, previous = both_windows { |target| records(target).series(target, grouping) }

      {
        grouping: grouping,
        rows: current,
        previous_totals: previous && current.each_index.map { |index| previous[index]&.fetch(:records) }
      }
    end

    def calls_summary
      current, previous = both_windows { |target| attempts(target).summary }
      record_summary = records(window).summary

      {
        metrics: {
          attempts: compare(current, previous) { |summary| Metric.count(summary[:attempts]) },
          answered: compare(current, previous) { |summary| Metric.count(summary[:answered]) },
          answer_rate: compare(current, previous) { |summary| Metric.rate(summary[:answered], summary[:answer_base]) },
          median_duration: compare(current, previous) { |summary| Metric.duration(summary[:median_duration], summary[:with_duration]) },
          average_duration: compare(current, previous) { |summary| Metric.duration(summary[:average_duration], summary[:with_duration]) },
          duration_coverage: compare(current, previous) { |summary| Metric.rate(summary[:with_duration], summary[:answered]) }
        },
        attempts_per_record: Metric.average(record_summary[:attempts_sum], record_summary[:attempts_reported]),
        statuses: current.slice(:answered, :not_answered, :failed, :other_status),
        results: current[:results],
        p90_duration: Metric.duration(current[:p90_duration], current[:with_duration]),
        duration_bins: current[:duration_bins]
      }
    end

    def qualification_query(target_window)
      batches = @scope.validated_batches(target_window)
      QualificationQuery.new(
        batches: batches,
        opportunities: @scope.commercial_opportunities_for(batches),
        searches: @scope.discovery_searches(target_window),
        discovery_batches: @scope.discovery_batches,
        reviews: @scope.audit_reviews(target_window),
        review_batches: @scope.review_batches
      )
    end

    def qualification_summary
      current, previous = both_windows do |target|
        query = qualification_query(target)
        query.outcomes.merge(query.funnel)
      end

      {
        metrics: {
          qualified: compare(current, previous) { |summary| Metric.count(summary[:qualified]) },
          qualification_rate: compare(current, previous) { |summary| Metric.rate(summary[:qualified], summary[:with_outcome]) },
          opportunities: compare(current, previous) { |summary| Metric.count(summary[:opportunities]) },
          collected: compare(current, previous) { |summary| Metric.count(summary[:collected]) }
        },
        by_outcome: current[:by_outcome],
        by_source: current[:by_source].transform_values do |source|
          source.merge(qualification_rate: Metric.rate(source[:qualified], source[:with_outcome]))
        end,
        funnel: [
          [ :records, current[:records] ],
          [ :qualified, current[:qualified] ],
          [ :opportunities, current[:funnel_opportunities] ],
          [ :collected, current[:funnel_collected] ]
        ],
        outside_funnel: current[:outside_funnel]
      }
    end

    def searches_summary
      current, previous = both_windows { |target| qualification_query(target).searches }

      {
        metrics: { searches: compare(current, previous) { |summary| Metric.count(summary[:searches]) } },
        found: current[:found],
        conversion: Metric.rate(current[:converted], current[:searches]),
        segments: current[:segments]
      }
    end

    def reviews_summary
      summary = qualification_query(window).reviews

      {
        reviews: Metric.count(summary[:reviews]),
        altered: Metric.rate(summary[:altered], summary[:reviews] - summary[:unmatched]),
        unmatched: summary[:unmatched]
      }
    end

    def batches_summary
      current, previous = both_windows { |target| BatchesQuery.new(@scope.created_batches(target)).summary }

      {
        metrics: {
          batches: compare(current, previous) { |summary| Metric.count(summary[:batches]) },
          records: compare(current, previous) { |summary| Metric.count(summary[:records]) },
          invalid_rate: compare(current, previous) { |summary| Metric.rate(summary[:invalid_rows], summary[:total_rows]) },
          median_wait: compare(current, previous) { |summary| Metric.duration(summary[:median_wait], summary[:with_wait]) },
          median_processing: compare(current, previous) { |summary| Metric.duration(summary[:median_processing], summary[:with_processing]) },
          p90_processing: compare(current, previous) { |summary| Metric.duration(summary[:p90_processing], summary[:with_processing]) }
        },
        processing_bins: current[:processing_bins],
        processing: { measured: current[:with_processing], fastest: current[:fastest], slowest: current[:slowest] }
      }
    end
  end
end
