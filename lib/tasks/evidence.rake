namespace :evidence do
  desc "Lista lotes sincronizados sem evidências (API separou resultado e evidências). PREVIEW=1 busca e compara sem gravar; APPLY=1 busca e grava; ACCOUNT_ID=... limita a uma conta."
  task backfill: :environment do
    account = Account.find(ENV["ACCOUNT_ID"]) if ENV["ACCOUNT_ID"].present?
    apply = ENV["APPLY"] == "1"
    preview = ENV["PREVIEW"] == "1"
    rows = Maintenance::RemoteEvidenceBackfill.new(account: account, apply: apply, preview: preview).call

    rows.each do |row|
      line = "#{row.supplier_import.display_code} conta=#{row.supplier_import.account_id} lote_remoto=#{row.supplier_import.remote_batch_id} #{row.result}"
      line += " registros_afetados=#{row.records_changed}" if apply || preview
      line += " erro=#{row.error}" if row.error
      puts line
    end
    if preview
      puts "PREVIEW: #{rows.count { |row| row.result == :would_apply }} lote(s), #{rows.sum(&:records_changed)} registro(s) seriam atualizados; #{rows.count { |row| row.result == :failed }} falha(s). Nada foi gravado."
    else
      puts "#{rows.size} lote(s) sem evidências#{apply ? '' : '. Nada foi gravado; PREVIEW=1 compara com a API antes de autorizar APPLY=1.'}"
    end
  end
end
