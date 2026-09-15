# LeadPulse

Plataforma web de prospecção B2B que encontra fornecedores por segmento e região, organiza lotes, valida contatos por chamadas automatizadas e devolve resultados auditáveis para a operação comercial.

## Recursos

- Busca de fornecedores com endereço, coordenadas e vínculo direto com o Google Maps.
- Importação e conferência de planilhas cadastrais ou de qualificação de fornecedores.
- Validação por voz com aviso de chamada automatizada, transcrição e tratamento de recusa.
- Acompanhamento de status, auditoria humana, exportação e anonimização de evidências.
- Política LGPD por conta, com base legal, finalidade e prazo de retenção.
- Integração externa por Bearer token com a API de validação.

## Arquitetura

O Rails é responsável pela experiência web, autenticação, organização dos lotes e espelhamento do estado operacional. A API `api_confaith_ai` mantém credenciais dos provedores, executa busca e validação, integra Twilio e OpenAI Realtime e processa eventos assíncronos por SQS.

Em produção, a API usa PostgreSQL, migrations Alembic e o padrão outbox/inbox para publicação idempotente de eventos. O web usa PostgreSQL e sincroniza o status dos lotes periodicamente e sob demanda.

## Stack

- Ruby on Rails 8, Hotwire, Stimulus e Tailwind CSS
- PostgreSQL 16
- FastAPI, SQLAlchemy e Alembic
- Amazon SQS
- Twilio Voice e Media Streams
- OpenAI Realtime
- Leaflet, OpenStreetMap e Nominatim para mapas e localização

## Execução local

```bash
docker compose -f compose.local.yml up -d db
bundle install
bin/rails db:prepare
bin/dev
```

Configure `VALIDATION_API_BASE_URL` no `.env` do web. Em produção, forneça também `RAILS_MASTER_KEY` pelo gerenciador de segredos da infraestrutura. As credenciais de Twilio e OpenAI pertencem à API e devem ser configuradas no ambiente da `api_confaith_ai`. O mapa usa OpenStreetMap e não exige chave no navegador.

### Busca assíncrona local

No ambiente de desenvolvimento, a busca de fornecedores usa o `ActiveJob` com o adaptador `async` do Rails. Ao iniciar uma busca, o registro aparece imediatamente como **Na fila**, muda para **Processando** e a tela acompanha o estado até **Concluída** ou **Falhou**. O navegador permanece livre enquanto o job chama a API.

Não é necessário iniciar um worker adicional: o job roda dentro do processo iniciado por `bin/dev`. Mantenha também a API `api_confaith_ai` em execução na URL definida por `VALIDATION_API_BASE_URL`. Como a fila local fica em memória, reiniciar o Rails durante uma busca interrompe esse job; em produção, o projeto usa uma fila persistente.

## Verificação

```bash
bin/rails db:test:prepare test
bin/rails test:system
bin/rubocop
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
```
