# Segurança — Fase 0 e incidente C1

C1 permanece aberto. O histórico contém material comprometido; remover um arquivo ou recifrar credentials sem trocar os segredos internos não elimina o incidente. Nenhum ambiente real foi inspecionado ou alterado nesta execução.

## Proteções locais

- `bin/security_check` rejeita caminhos de segredo na index. Com `--deployment`, verifica também a master key e o secret_key_base por fingerprints, sem imprimir valores.
- O boot de produção repete a rejeição de chaves comprometidas; não existe bypass para deploy.
- A chave Devise fixa foi removida; Devise usa a configuração Rails. Tokens já emitidos podem ser invalidados: o operador deve coordenar esta mudança.
- `scripts/scan_secrets.py` examina os bytes staged com Gitleaks 8.30.1 e saída redigida. `.github/workflows/secrets.yml` verifica o SHA-256 do executável antes de executá-lo.
- `.githooks/pre-commit` está pronto. Sua instalação (`git config core.hooksPath .githooks`) é uma ação posterior do operador, não realizada aqui para preservar a configuração Git.
- A index anterior ainda contém a chave fixa Devise; o scanner deve falhar até o operador revisar e stagear a remoção já feita no working tree. Não crie uma exceção para esse segredo.

## Procedimento C1 a aprovar antes da execução

1. Inventariar ambientes, versões de credentials, cofre de segredos, jobs, sessões e credenciais externas potencialmente expostas. Comparar somente fingerprints; registrar quem verificou cada ambiente. A ausência de evidência de uso não comprova ausência de exposição.
2. Criar backup protegido e testar restauração do banco, credentials cifradas e configuração. Identificar tokens Rails cifrados com o secret_key_base antigo, tokens legados e as sessões mobile derivadas dessa chave.
3. Em cópia isolada, o operador prepara uma nova master key e novos segredos pelo cofre. Não passar valores em argumentos do shell, tickets, logs ou histórico. Descriptografar credentials antigas apenas em diretório temporário 0700; recifrar com a nova chave usando `ActiveSupport::EncryptedFile`; verificar que o novo arquivo é legível com a chave nova e que a antiga não o abre. Verificar os campos exigidos sem imprimi-los. Não reutilizar o secret_key_base exposto.
4. Ensaiar a migração dos tokens contra uma cópia descartável do banco. `Maintenance::ReencryptValidationTokens.new(old_secret: old_value, new_secret: new_value).call` é dry-run por padrão: retorna candidatos e zero mudanças. Os valores vêm do cofre. O teste de round-trip é executado antes de qualquer escrita. Entradas ilegíveis/legadas abortam a transação: tratá-las em procedimento explícito, sem remover o fallback de compatibilidade silenciosamente.
5. Executar o mesmo ensaio com `apply: true` somente na cópia. Repetir: a segunda execução deve alterar zero linhas. Testar autenticação e descriptografia com a chave nova; planejar encerramento de sessões web/mobile e invalidação de links de recuperação já emitidos.
6. Inventariar e rotacionar individualmente os tokens externos potencialmente expostos com cada fornecedor/cliente. A recifragem local não revoga tokens externos. Esta etapa depende de autorização e janela coordenada.
7. Após aprovação específica, suspender writers em janela de manutenção, repetir backup consistente e migração transacional, publicar credentials/chaves novas de maneira atômica e executar `RAILS_ENV=production bin/security_check --deployment` antes de liberar o serviço. Não executar este comando na máquina local esperando um resultado verde com a chave exposta.
8. Confirmar boot, autenticação, jobs e isolamento com tráfego controlado; registrar fingerprints ativos e revogação das credenciais antigas. O rollback deve restaurar banco e configuração compatíveis em conjunto e manter o serviço isolado; não reabrir produção usando uma chave comprometida.
9. Tratar a exposição histórica com o responsável pelo repositório. Reescrita de histórico e ações no remoto exigem aprovação separada e não substituem rotação. Fechar C1 somente com evidência de cada ambiente e revogação/rotação concluída.

## TLS, CSP e autenticação

Produção exige HTTPS (`force_ssl`), HSTS inicial de um dia sem subdomínios/preload, e `RAILS_ASSUME_SSL=true` apenas quando o proxy confiável termina TLS. A origem de áudio usa `VALIDATION_API_WS_BASE_URL`, ou deriva de `VALIDATION_API_BASE_URL`; produção exige uma origem `wss://host[:porta]`, sem credenciais, query ou fragmento. Prefixos de caminho de reverse proxy são preservados na URL de áudio e removidos da origem CSP. Configure isso antes do deploy.

A CSP permanece report-only, com nonce para scripts e origem de áudio em connect-src. A coleta limita corpo e logs e não registra URLs/tickets. A política deve ser avaliada com o frontend antes de enforcement, conforme o [guia oficial Rails](https://guides.rubyonrails.org/security.html#content-security-policy-header).

Login e recuperação de senha têm orçamentos independentes por IP e identidade+IP, usando o cache compartilhado Solid Cache em produção. Falha no contador bloqueia a tentativa com 503. Validar a infraestrutura de cache na preparação operacional.

## Exceção específica Brakeman

`config/brakeman.ignore` preserva somente o fingerprint de mass assignment de `role` em `TeamInvitationsController`: acesso exige admin no controller e em `Accounts::TeamManagement`; papel tem validação de inclusão e constraint. Escolher papel é parte da operação autorizada. Não é uma supressão geral.

Brakeman 8.1.0 é fixado no lockfile; a análise estática não consulta a versão mais recente em cada execução. Atualizações ficam sob revisão de dependências, preservando análise offline e reprodutível.
