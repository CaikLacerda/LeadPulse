# Brief — LeadPulse

Resumo executivo para quem vai planejar a landing page. Os detalhes estão nos demais documentos desta pasta.

Legenda usada em todos os documentos:

- **CURRENT**: existe e foi conferido no código.
- **PARTIAL**: há código, mas incompleto ou só em fluxo de teste; não é recurso de produto em produção.
- **PLANNED**: previsto no código ou na documentação (por exemplo, opção "em breve"), sem implementação.
- **EVALUATED**: tecnologia testada ou considerada, sem papel de produto.
- **OPTIONAL**: depende de configuração.
- **FUTURE**: visão de produto, sem código.

## O que é o LeadPulse

Plataforma B2B que conduz processos empresariais por meio de conversas por voz com IA. Hoje ela executa workflows predefinidos de ligação: a IA liga, se identifica, faz as perguntas do processo, interpreta as respostas, registra o resultado com evidências e permite revisão humana. Também oferece um ambiente para simular e avaliar o agente antes de ligar para pessoas reais.

## Origem

O LeadPulse nasceu como TCC, a partir de um caso concreto: **qualificar e validar telefones de fornecedores com IA conversacional por voz**. A IA confirma se o telefone pertence à empresa, se ela atende o segmento, se há interesse comercial, e coleta número e horário para retorno.

Esse caso continua importante: é a origem, a prova de conceito, o primeiro workflow real (`supplier_validation`), o cenário oficial de testes e a demonstração prática da arquitetura. **Não é o limite do produto.**

## Problema

Empresas fazem por telefone muitos processos repetitivos e estruturados: confirmações, triagens, qualificações, cobranças, validações. Esse trabalho é caro, difícil de escalar, inconsistente e pouco rastreável. Agentes de IA de voz são difíceis de testar antes de chegar ao cliente, e cada novo processo costuma exigir uma automação feita sob medida.

## Solução

Um motor de conversa por voz guiado por workflow, em que cada processo é uma sequência de etapas, perguntas, regras e resultados, com:

- execução real por telefone (**CURRENT**);
- evidências: transcrição, gravação opcional, resultado por etapa, revisão humana (**CURRENT**);
- simulação IA × IA com cenários e avaliação por campo (**CURRENT**);
- workflows criados pelo próprio cliente (**FUTURE**);
- ações em sistemas externos durante a conversa (**FUTURE**).

## Produto atual (CURRENT)

- Ligações automatizadas com Twilio (telefonia) e OpenAI Realtime (voz), usando as contas de cada empresa.
- Três fluxos predefinidos sobre o mesmo motor: validação cadastral, validação de fornecedor por segmento e retorno comercial.
- Lotes importados por planilha ou API, com status, tentativas, transcrição, gravação opcional e exportação.
- Fallback por e-mail quando a ligação não é atendida.
- Auditoria com revisão humana, Analytics, API de BI, LGPD (base legal, retenção, anonimização, recusa).
- Ambiente de Simulação: o agente de produção conversa com uma contraparte simulada por IA, em 15 cenários do workflow de fornecedor, com avaliação automática e monitor de áudio ao vivo.
- Multiempresa, com equipe, papéis e convites.

## Visão futura (FUTURE)

Custom Workflows: a empresa descreve o processo (abertura, perguntas, dados a coletar, decisões, consultas, ações, caminhos alternativos, fallback, transferência para humano, encerramento) e a plataforma executa a conversa. Cada workflow é testado em simulação antes de ir para produção, e a arquitetura não depende de um único provedor de IA, telefonia ou mensageria.

## Público

Empresas, especialmente pequenas e médias, com processos repetitivos ou de alto volume feitos por telefone: atendimento, suporte, comercial, cobrança, operações, logística, saúde e serviços. Quem decide são gestores de operação, atendimento, comercial e cobrança, líderes de inovação e tecnologia. Desenvolvedores entram como responsáveis pela integração.

## Proposta de valor

O LeadPulse transforma ligações em processos configuráveis, executáveis e observáveis. A voz é a interface. O valor está em ligar conversa, inteligência, workflow, dados e sistemas, com evidência de cada resultado e testes antes da produção.

## Objetivo da landing page

1. Posicionar o LeadPulse como infraestrutura de automação conversacional para processos reais, não como chatbot nem como validador de fornecedores.
2. Mostrar o produto real com telas reais.
3. Separar com honestidade o que existe hoje do que é visão.
4. Gerar interesse qualificado de empresas. O CTA comercial ainda está em definição (ver `CONTENT_DIRECTION.md`).

## Mensagem central

> **"Crie o fluxo. A IA conduz a conversa."**

Direções equivalentes: "Transforme conversas em processos." / "Workflows inteligentes. Conversas naturais. Ações reais." / "A camada inteligente para operações por voz." A headline final não foi escolhida. O Astra propõe opções.

Atenção: "Crie o fluxo" descreve a visão. Hoje os workflows são predefinidos. A página não pode sugerir que o cliente já cria fluxos sozinho (ver `CONTENT_DIRECTION.md`, seção "Claims").
