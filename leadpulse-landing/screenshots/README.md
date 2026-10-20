# Screenshots do produto

## Princípio

A landing deve mostrar **telas reais do LeadPulse**. Interfaces inventadas, mockups gerados por IA e dashboards ilustrativos não devem ser usados.

Quando faltar uma tela real para uma seção, há três caminhos: capturar a tela, usar um recorte de uma tela real existente ou deixar a seção sem imagem. Uma interface fictícia não é opção. Se uma ilustração conceitual for indispensável, por exemplo para um recurso futuro, ela precisa parecer diagrama, não produto, e vir identificada como visão futura.

## Inventário

Todas as telas usam **dados fictícios de demonstração**: empresas como "Distribuidora Atlântico", "Atlas Rótulos" e "Embalagens Horizonte", a pessoa "Marina Costa" e telefones `+55 11 9000-02xxx`. Os números nas telas (taxas, totais, durações) **não são resultados reais** e não podem virar argumento comercial.

| Arquivo | Tela | Origem | Tema | Tamanho | Status no código |
| --- | --- | --- | --- | --- | --- |
| `01-simulation-live-desktop-1280.png` | Simulação ao vivo: status, tempo, workflow, cenário, turnos; "canal de voz" com agente e contraparte; monitor de áudio | `tmp/orbital-ui/desktop.png` | escuro | 1280 × 937 | em andamento (ver ressalvas) |
| `02-simulation-live-full-page.png` | Mesma tela, página inteira, com a conversa ao vivo (balões do agente e do fornecedor simulado) | `tmp/orbital-ui/desktop-full.png` | escuro | 1265 × 1422 | em andamento |
| `03-simulation-live-mobile-390.png` | Mesma tela em mobile | `tmp/orbital-ui/mobile.png` | escuro | 390 × 1007 | em andamento |
| `04-analytics-overview-1600.webp` | Analytics: indicadores de registros, taxas de validação, confirmação e atendimento, duração mediana, lotes; gráfico diário por resultado | `app/assets/images/landing/produto-analytics-1600.webp` | claro | 1600 × 1173 | no `main` |
| `05-call-transcript-human-review-1200.webp` | Conversa na ordem real (IA/cliente, com a etapa de cada fala), evidência e revisão humana do resultado | `app/assets/images/landing/produto-chamada-1200.webp` | claro | 1200 × 582 | no `main` |
| `06-batch-records-1200.webp` | Registros de um lote: empresa, telefone, resultado (qualificado, não atendida, não fornece o segmento, inconclusiva) e tentativas | `app/assets/images/landing/produto-lote-1200.webp` | claro | 1200 × 529 | no `main` |
| `07-supplier-search-1200.webp` | Busca de fornecedores por segmento e região | `app/assets/images/landing/produto-busca-1200.webp` | claro | 1200 × 450 | no `main` |

### Ressalvas

- **01–03**: render offline da view real `simulations/show` (`tmp/orbital-ui/render.rb`), com o polling da API simulado. Elas usam o visual com o "orb" central (`app/views/simulations/_orb.html.erb`, `simulation_voice.css`), que em 15/10/2026 ainda **não estava commitado** na branch `feat/simulacoes`. A fonte Inter não carregou no render, e o texto aparece em fonte de fallback. Antes de usar em produção, recapturar no navegador com a versão final da tela.
- **04–07**: recortes já usados na landing pública atual, em tema claro. O hero da nova landing é escuro. O Astra deve decidir como apresentar telas claras sobre fundo escuro (moldura, recorte, versão dark do workspace) ou pedir novas capturas no tema escuro, que o workspace já suporta.
- **01–03** mostram o workflow `supplier_validation` ("Validação de fornecedor"). Na landing, essa tela deve aparecer como **exemplo** de workflow, não como o propósito do produto.
- Os textos `CA…` na captura 06 são identificadores de chamada da demonstração.

## Telas desejadas que ainda faltam

Prioridade para a narrativa "workflow → simulação → avaliação → operação":

| Prioridade | Tela | Rota no Rails | Por que importa |
| --- | --- | --- | --- |
| alta | Lista de simulações | `/simulacoes` | Mostra testes recorrentes do agente |
| alta | Nova simulação: escolha de workflow, cenário e modo | `/simulacoes/new` | Mostra cenários (favorável, parcial, difícil) e o conceito de workflow |
| alta | Resultado da simulação: avaliação por campo, precisão, fidelidade, métricas | `/simulacoes/:id` (concluída) | Prova a camada de confiabilidade |
| média | Detalhe do lote: linha do tempo e "Evidências e LGPD" | `/dados/:id` | Rastreabilidade e conformidade |
| média | Auditoria com revisão humana | `/auditoria` | Controle humano sobre a IA |
| média | Configurações de provedores (Twilio, OpenAI) | `/configuracoes/twilio`, `/configuracoes/openai` | Mostra que a empresa usa as próprias contas. **Ocultar chaves e tokens.** |
| média | Retornos comerciais | `/comercial` | Resultado de negócio após a conversa |
| baixa | Analytics de chamadas e qualificação | `/analytics/chamadas`, `/analytics/qualificacao` | Observabilidade |
| baixa | Tokens de BI e página para desenvolvedores | `/configuracoes/tokens-bi`, `/for-devs` | Integração com sistemas |
| baixa | Equipe e convites | `/equipe` | Multiempresa e papéis |

Por que não capturei novas telas: o navegador do Playwright MCP exige instalar o Chrome, e a regra desta tarefa é não instalar dependências. Também não há credenciais de demonstração no repositório (`db/seeds.rb` não cria usuário). O Rails já estava rodando em `localhost:3000`, mas não fiz login nem criei dados.

## Checklist de captura

1. Use uma conta de demonstração com **dados fictícios**. Nada de dados pessoais reais, chaves, tokens, números reais ou gravações reais.
2. Mesma largura em toda a série: 1440 ou 1600 px, densidade 2× (retina).
3. Um tema por série. Para a landing escura, prefira o tema escuro do workspace.
4. Esconda badges de notificação, avisos de ambiente e dados de depuração.
5. Capture estados significativos: simulação concluída com avaliação, lote com resultados variados.
6. Nome: `NN-area-descricao-LARGURA.png`, por exemplo `08-simulation-new-1440.png`. PNG ou WebP sem perda.
7. Registre no inventário acima: arquivo, tela, rota, tema, tamanho, data e branch/commit.
8. Não edite a interface na imagem (textos, números, telas montadas). Recortar é permitido.
