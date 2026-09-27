module Maintenance
  # Aplica a correção histórica de finished_at somente nos registros comprovadamente seguros
  # da prévia (FinishedAtCorrectionPreview):
  #
  # - o valor gravado é exatamente a leitura antiga do payload (sem fuso, lido como Brasília),
  #   o que prova que o erro veio do parser;
  # - o valor novo vem do próprio payload e não gera anomalia (fim antes do início, antes da
  #   criação ou duração implausível).
  #
  # Os demais ficam como estão. Antes de gravar, salva um JSON com antes/depois de cada
  # registro alterado, que permite conferir e desfazer (restore).
  class FinishedAtCorrection
    MODELS = { "Lote" => SupplierImport, "Coleta comercial" => CommercialOpportunity }.freeze

    Result = Data.define(:applied, :kept, :backup_path)

    def initialize(backup_dir: Rails.root.join("tmp/backups"), now: Time.current)
      @backup_dir = Pathname(backup_dir)
      @now = now
    end

    def call
      rows = FinishedAtCorrectionPreview.new.call.select(&:change?)
      safe, kept = rows.partition { |row| safe?(row) }
      backup_path = write_backup(safe)

      ActiveRecord::Base.transaction do
        safe.each do |row|
          updated = MODELS.fetch(row.kind).where(id: row.id, finished_at: row.current_value)
            .update_all(finished_at: row.new_value, updated_at: @now)
          raise ActiveRecord::Rollback, "#{row.code} mudou durante a correção" unless updated == 1
        end
      end

      Result.new(applied: safe, kept: kept, backup_path: backup_path)
    end

    def self.restore(path)
      entries = JSON.parse(File.read(path))
      ActiveRecord::Base.transaction do
        entries.each do |entry|
          MODELS.fetch(entry["kind"]).where(id: entry["id"]).update_all(finished_at: Time.iso8601(entry["before"]))
        end
      end
      entries.size
    end

    private

    def safe?(row)
      row.anomalies.empty? &&
        row.payload_value.present? &&
        Time.zone.parse(row.payload_value) == row.current_value
    rescue ArgumentError
      false
    end

    def write_backup(rows)
      FileUtils.mkdir_p(@backup_dir)
      path = @backup_dir.join("finished_at-#{@now.utc.strftime('%Y%m%d-%H%M%S')}.json")
      entries = rows.map do |row|
        { kind: row.kind, id: row.id, code: row.code, before: row.current_value.utc.iso8601(6), after: row.new_value.utc.iso8601(6), payload: row.payload_value }
      end
      File.write(path, JSON.pretty_generate(entries))
      path
    end
  end
end
