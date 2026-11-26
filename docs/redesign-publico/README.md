# Redesign público do LeadPulse

Rodada concluída em 03/10/2026 na branch `redesign/telas-publicas`. Base: `30faedd`.

[Abrir comparação visual interativa](comparacao.html). As imagens ficam no repositório, sem depender de arquivos temporários.

## Análise e composição

A base já tinha CTA azul, menu responsivo, erros próximos aos campos, imagens reais e SEO. A fotografia mencionada no briefing já havia sido removida antes desta rodada. O problema restante era a distribuição: autenticação ocupava toda a largura, enquanto o produto da landing vinha depois do texto, muito abaixo do topo.

| Tela | Ponto forte existente | Problema encontrado | Proposta implementada |
| --- | --- | --- | --- |
| Login | Formulário legível, foco e mostrar senha | Painel largo com ilustração de chamada e formulário afastado | Composição limitada, tela real de auditoria e benefícios compactos |
| Cadastro | Campos verticais, erros inline e etapas informativas | Painel institucional pouco preenchido | Tela real do lote e etapas resumidas no mesmo sistema do login |
| Landing | Produto real, seções alternadas e navegação completa | Screenshot abaixo do texto e hero muito alto | Texto e produto lado a lado no desktop; produto logo após o CTA no mobile |

Wireframes apresentados antes da implementação:

1. Login desktop: `[marca / mensagem / auditoria real / benefícios / legal] | [título / e-mail / senha / checkbox / CTA / cadastro]`.
2. Login mobile: `marca → headline curta → formulário → CTA → links → legal`.
3. Cadastro desktop: `[marca / mensagem / lote real / três etapas / legal] | [título / quatro campos / termos / CTA / entrar]`.
4. Cadastro mobile: `marca → headline curta → campos verticais → termos → CTA → entrar → legal`.
5. Hero desktop: `[headline / descrição / CTAs] | [Analytics real / legenda] → benefícios`.
6. Hero mobile: `headline → descrição → CTAs → screenshot → benefícios`.
7. Como funciona: `Encontre → Ligue → Valide → Analise`, horizontal no desktop e vertical no mobile.
8. Produto: `texto | busca`, depois `chamada | texto`, depois `texto | lote`; empilhamento no mobile.

## A–B. Arquivos e componentes

| Arquivo | Mudança |
| --- | --- |
| `app/assets/tailwind/layouts/auth.css` | Composição limitada, densidade, previews e reduced motion |
| `app/assets/tailwind/layouts/public.css` | Moldura e legenda compartilhadas das imagens |
| `app/assets/tailwind/pages/landing.css` | Hero em duas colunas e escala tipográfica |
| `app/views/devise/sessions/new.html.erb` | Descrição curta do login |
| `app/views/devise/registrations/new.html.erb` | Contexto do cadastro |
| `app/views/devise/shared/_brand_panel.html.erb` | Produto real, benefícios e etapas |
| `app/views/devise/shared/_password_field.html.erb` | Ocultação visual ao iniciar envio Turbo |
| `app/views/shared/_product_screenshot.html.erb` | Novo componente: imagem responsiva, prioridade, dimensões, alt e legenda |
| `app/views/pages/_public_landing.html.erb` | Hero, texto, OpenGraph e uso do componente |
| `test/controllers/pages_controller_test.rb` | Atualização das duas expectativas de texto |
| `docs/redesign-publico/` | Relatório, comparação, capturas, resultados e scripts de verificação |

Reutilizados: layout Devise, painel institucional com variantes, helper de erros, campo de senha, botões, tokens, navbar, footer e controladores Stimulus existentes. Nenhum framework ou dependência foi adicionado ao aplicativo.

## C–F. Login, cadastro, landing e responsividade

Autenticação: quadro com largura máxima de 1320 px, proporção 43/57 e formulário de até 432 px. Superfícies planas navy e branca; azul funcional e laranja apenas nos acentos. A ilustração de chamada foi substituída pela interface real de auditoria. O cadastro ganhou preview de lote e mantém as etapas informativas, sem wizard. A senha e a confirmação continuam verticais.

Em telas abaixo de 1024 px, o painel vira marca e headline curta; preview, benefícios e etapas deixam de ocupar espaço. Em 1024 × 768, o formulário e o rodapé cabem sem rolagem vertical. Em 390 px, o cadastro rola naturalmente para preservar campos, CTA e textos legais. Em 1920 px, a composição permanece limitada e centralizada.

Landing: headline mais curta, texto à esquerda e Analytics real à direita. Os três benefícios ficam abaixo. Busca, chamadas e auditoria reutilizam a mesma moldura, com legendas explícitas de demonstração. Como funciona, recursos, planos, sobre, FAQ, contato, navbar e footer foram revisados e preservados. Não foram inventados clientes, preços, certificações ou resultados comerciais.

| Medida | Antes | Depois |
| --- | ---: | ---: |
| Topo da imagem do hero em 1440 px | 540 px | 130 px |
| Topo da imagem do hero em 390 px | 702 px | 479 px |
| Altura total da landing em 1440 px | 5570 px | 4892 px |
| Largura do formulário no desktop | 416 px | 432 px |

Resultados completos de geometria: [antes](antes.json) e [depois](depois.json). Todas as 15 combinações finais retornaram HTTP 200, sem overflow horizontal nem exceções JavaScript.

## G. Acessibilidade

axe-core: **15 auditorias, zero violações e zero verificações incompletas** nas três páginas, em 390, 768, 1024, 1440 e 1920 px; regras WCAG 2 A/AA, WCAG 2.1 AA e boas práticas. [Resultado](acessibilidade.json).

Verificados no Chromium: navegação do menu por teclado, Enter, Tab, Escape com retorno do foco, fechamento por âncora, checkbox e mostrar/ocultar senha por Enter e Espaço. Erros retornados pelo backend mantêm resumo com alerta, texto junto ao campo, `aria-invalid` e `aria-describedby`. Imagens têm alt, legenda e dimensões. Os links legais abrem corretamente.

O envio exibe “Entrando…”, desabilita o botão e bloqueia cliques duplicados. Com movimento reduzido, o spinner fica parado e o texto permanece. O campo volta a ocultar a senha ao iniciar o envio Turbo. [Verificação desses estados](verificacao-final.json).

## H–I. Performance e SEO

As imagens WebP existentes foram reutilizadas sem alterar seus dados. `srcset` e `sizes` selecionam a resolução; o hero carrega imediatamente com prioridade alta, e os demais previews usam lazy loading. Largura e altura explícitas reservam o espaço.

Em 1440 px, DPR 1, o navegador selecionou a imagem do hero de 800 px, **34.156 bytes**, em vez da variante de 1600 px, **82.156 bytes**, necessária ao layout anterior de 1088 px. A variante é cerca de 58% menor. Isso compara os arquivos, não é medição de LCP. Não houve Lighthouse ou teste de rede móvel real. Não entrou biblioteca de animação nem bundle adicional no produto.

Preservados title, descrição, canonical gerado pela URL, um único h1, hierarquia de seções, OpenGraph e imagem social existente. O título OpenGraph acompanha a nova mensagem. Os URLs locais nos resultados JSON correspondem ao servidor de teste.

## J. Capturas

Todas as capturas são de página inteira; há também primeira dobra em 1440 px. Dados nas telas do produto são de demonstração.

| Tela / largura | Antes | Depois |
| --- | --- | --- |
| Login 390 | [imagem](screenshots/antes/login-390.jpg) | [imagem](screenshots/depois/login-390.jpg) |
| Login 1024 | [imagem](screenshots/antes/login-1024.jpg) | [imagem](screenshots/depois/login-1024.jpg) |
| Login 1440 | [imagem](screenshots/antes/login-1440.jpg) | [imagem](screenshots/depois/login-1440.jpg) |
| Cadastro 390 | [imagem](screenshots/antes/cadastro-390.jpg) | [imagem](screenshots/depois/cadastro-390.jpg) |
| Cadastro 1024 | [imagem](screenshots/antes/cadastro-1024.jpg) | [imagem](screenshots/depois/cadastro-1024.jpg) |
| Cadastro 1440 | [imagem](screenshots/antes/cadastro-1440.jpg) | [imagem](screenshots/depois/cadastro-1440.jpg) |
| Landing 390 | [imagem](screenshots/antes/landing-390.jpg) | [imagem](screenshots/depois/landing-390.jpg) |
| Landing 1024 | [imagem](screenshots/antes/landing-1024.jpg) | [imagem](screenshots/depois/landing-1024.jpg) |
| Landing 1440 | [imagem](screenshots/antes/landing-1440.jpg) | [imagem](screenshots/depois/landing-1440.jpg) |

Capturas adicionais finais: [login 768](screenshots/depois/login-768.jpg), [cadastro 768](screenshots/depois/cadastro-768.jpg), [landing 768](screenshots/depois/landing-768.jpg), [login 1920](screenshots/depois/login-1920.jpg), [cadastro 1920](screenshots/depois/cadastro-1920.jpg), [landing 1920](screenshots/depois/landing-1920.jpg), [erros no cadastro mobile](screenshots/depois/cadastro-erros-390.jpg).

## K–L. Validação, problemas e limites

| Verificação | Resultado |
| --- | --- |
| Suíte Rails | 298 testes, 2138 assertions, zero falhas/erros |
| System tests, driver rack_test | 4 testes, 16 assertions, zero falhas/erros; cadastro válido, login, erros e solicitação de reset |
| RuboCop | 253 arquivos, nenhuma infração |
| Build Tailwind | Sucesso |
| Chromium + axe | 15 combinações, zero violações |
| Interações em navegador | Menu, teclado, checkbox, senha, links legais/reset, cadastro inválido, login inválido, loading e envio único aprovados |

[Saídas dos comandos](validacao.txt). A suíte completa passou após a implementação; os system tests foram repetidos após o ajuste final do evento visual de senha. Browser tests rodaram com banco e entrega de e-mail de teste, sem chamadas reais aos provedores.

Problemas tratados: composição muito larga, produto abaixo da dobra, overflow vertical evitável no cadastro em tela baixa e evento de ocultação de senha que o submit interceptado pelo Turbo não propagava até `window`. O evento `turbo:submit-start` agora também aciona o controlador já existente, sem mudar regras de login ou sessão.

O console registrou apenas o HTTP 422 esperado ao enviar cadastro inválido. Nenhuma exceção JavaScript foi capturada. A validação automatizada não substitui leitura por leitor de tela, testes em Safari/Firefox ou gerenciadores de senha reais; estes não foram executados. Em 1440 × 900, o cadastro tem altura total de 901 px, sem conteúdo cortado. Controllers, models, rotas, API, tenancy, permissões, configuração Devise e telas internas não foram alterados.

Reprodução opcional do navegador: scripts em `scripts/` usam Playwright e axe-core instalados fora do aplicativo. Exporte `NODE_PATH` para esse `node_modules`; `BROWSER_EXECUTABLE` é opcional se o Chromium do Playwright já estiver instalado. Suba `RAILS_ENV=test bin/rails server -b 127.0.0.1 -p 3107`, depois execute `node docs/redesign-publico/scripts/capture.cjs depois`, `node docs/redesign-publico/scripts/verify.cjs` e `node docs/redesign-publico/scripts/final-check.cjs`. `PUBLIC_UI_URL` permite trocar o endereço. A captura substitui os artefatos da fase indicada; execute somente contra ambiente de teste.

## M. Commits locais

- `7349483` — `ui: bring real product screens into public authentication`
- `d86dacb` — `ui: move the product into the public landing hero`
- Commit de documentação — `docs: record public UI visual and accessibility review` (contém este relatório e os artefatos).

Nenhum push realizado.
