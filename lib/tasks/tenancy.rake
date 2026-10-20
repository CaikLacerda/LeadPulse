namespace :tenancy do
  desc "Verifica a integridade do tenancy por empresa (somente leitura)."
  task verify: :environment do
    problems = Tenancy::IntegrityCheck.new.call
    if problems.empty?
      puts "Tenancy íntegro: todo dado de negócio pertence a uma empresa, filhos de lote estão na empresa do lote e toda empresa ativa tem admin."
    else
      problems.each { |problem| puts "PROBLEMA: #{problem.check} em #{problem.table} (#{problem.count})" }
      exit 1
    end
  end
end
