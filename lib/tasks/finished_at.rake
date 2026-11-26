namespace :finished_at do
  desc "Prévia (somente leitura) da correção histórica de finished_at. ACCOUNT_ID=... limita a uma conta."
  task dry_run: :environment do
    zone = ActiveSupport::TimeZone["America/Sao_Paulo"]
    format_time = ->(value) { value ? value.in_time_zone(zone).strftime("%Y-%m-%d %H:%M:%S %:z") : "—" }
    format_difference = lambda do |seconds|
      next "—" if seconds.nil?
      next "0" if seconds.zero?

      sign = seconds.negative? ? "-" : "+"
      hours, rest = seconds.abs.divmod(3600)
      "#{sign}#{hours.to_i}h#{format('%02d', (rest / 60).round)}min"
    end

    account = Account.find(ENV["ACCOUNT_ID"]) if ENV["ACCOUNT_ID"].present?
    rows = nil

    # Transação somente leitura: o banco recusa qualquer escrita feita por engano.
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET TRANSACTION READ ONLY")
      rows = Maintenance::FinishedAtCorrectionPreview.new(account: account).call
      raise ActiveRecord::Rollback
    end

    headers = [ "Tipo", "Registro", "Conta", "finished_at atual", "Valor original do payload", "Novo valor calculado", "Diferença", "Observação" ]
    table = rows.map do |row|
      [
        row.kind,
        row.code,
        row.account_id.to_s,
        format_time.call(row.current_value),
        row.payload_value || "—",
        row.change? ? format_time.call(row.new_value) : "sem alteração",
        format_difference.call(row.difference),
        row.anomalies.join("; ")
      ]
    end
    widths = headers.each_index.map { |index| ([ headers[index] ] + table.map { |line| line[index] }).map(&:length).max }
    print_line = ->(values) { puts values.each_with_index.map { |value, index| value.ljust(widths[index]) }.join(" | ") }

    puts "Horários exibidos em America/Sao_Paulo. Nenhum registro foi alterado."
    puts
    print_line.call(headers)
    puts widths.map { |width| "-" * width }.join("-+-")
    table.each { |line| print_line.call(line) }
    puts
    puts "Registros analisados: #{rows.size}"
    puts "Com alteração proposta: #{rows.count(&:change?)}"
    rows.group_by { |row| format_difference.call(row.difference) }.sort_by { |_, grouped| -grouped.size }.each do |difference, grouped|
      puts "  diferença #{difference}: #{grouped.size}"
    end
    puts "Com anomalia para revisão manual: #{rows.count { |row| row.anomalies.any? }}"
  end

  desc "Aplica a correção de finished_at só nos registros seguros e salva antes/depois em tmp/backups."
  task apply: :environment do
    result = Maintenance::FinishedAtCorrection.new.call
    puts "Corrigidos: #{result.applied.size} (antes/depois em #{result.backup_path})"
    result.applied.each { |row| puts "  #{row.code}: #{row.current_value.utc.iso8601} -> #{row.new_value.utc.iso8601}" }
    puts "Preservados sem correção: #{result.kept.size}"
    result.kept.each { |row| puts "  #{row.code}: #{row.anomalies.join('; ').presence || 'valor gravado não corresponde à leitura antiga do payload'}" }
  end

  desc "Desfaz uma correção a partir do arquivo gerado por finished_at:apply. FILE=tmp/backups/finished_at-....json"
  task restore: :environment do
    path = ENV.fetch("FILE")
    puts "Restaurados: #{Maintenance::FinishedAtCorrection.restore(path)} registros de #{path}"
  end
end
