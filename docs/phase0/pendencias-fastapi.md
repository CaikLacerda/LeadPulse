# Cards de compatibilidade — FastAPI congelada B3

Nenhum dos 125 arquivos Python foi alterado. As correções abaixo exigem uma linha de evolução separada do snapshot B3 e aprovação explícita para mudar o código congelado. Os resultados experimentais devem continuar vinculados ao fingerprint original.

| Card | Evidência atual | Mudança coordenada e aceite |
|---|---|---|
| F0-API-01 — escopos de simulação | `app/api/routes/simulations.py` autentica tokens da empresa, mas não exige escopo de operador para criar/cancelar/ticket. Rails agora protege essas ações; acesso direto à API permanece dependente de correção. | Introduzir escopos com migração explícita dos tokens atuais; criação/cancelamento/ticket negados a leitores; leitura entre empresas negada; compatibilidade dos clientes documentada. |
| F0-API-02 — injeção de eventos | `app/api/routes/validations.py` aceita call-events/whatsapp-events/email-events com a mesma autenticação de lote do cliente. | Inventariar emissores; criar credencial/escopo interno de ingestão; migrar consumidores antes de retirar permissão legada; testar 403 para token de cliente e integridade de callbacks assinados. |
| F0-API-03 — fallback OpenAI | `OpenAIRealtimeBridge._resolve_api_key` retorna a chave global quando o contexto não contém uma chave própria. | Falhar de forma explícita para tenant sem configuração; manter fluxos locais apenas por opção operacional explícita; testar ausência de cobrança cruzada. Não modificar runtime de voz da bateria B3. |
| F0-API-04 — instruções de estilo | `openai_realtime_bridge.py` concatena `resolved_style_instructions` e estilo global às instruções. | Separar dados de configuração das instruções confiáveis, limitar campos/valores e testar injeção. Exige novo protocolo de avaliação, sem reprocessar B3. |
| F0-API-05 — secrets legados | `app/utils/security.py:decrypt_provider_secret` aceita texto puro; chave de cifra tem fallback de configuração. Rails também preserva leitura legada por compatibilidade. | Inventário por contagens, dry-run e migração cifrada com backup, depois desativação explícita do fallback. Não imprimir valores nem rotacionar em massa sem operador. |
| F0-API-06 — SMTP SSRF | Schema aceita host arbitrário e `EmailService` usa `smtplib.SMTP` diretamente. | Política de egress, allowlist operacional e validação DNS/IP no ponto de conexão contra loopback, metadata, link-local e redes privadas não autorizadas; conter DNS rebinding e testar destinos proibidos. Definir exceções aprovadas para SMTP privado existente antes da migração. |

Esses riscos impedem declarar a base comercial pronta. Guardas Rails não substituem autorização e configuração seguras no serviço remoto.
