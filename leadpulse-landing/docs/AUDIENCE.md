# Público — LeadPulse

A landing fala primeiro com o **problema de negócio** e depois com a tecnologia. O LeadPulse não é uma ferramenta para desenvolvedores brincarem com agentes de IA. É infraestrutura de automação conversacional para processos reais.

## Empresas-alvo

Organizações com processos **repetitivos, estruturados ou de alto volume feitos por telefone**:

- pequenas e médias empresas (público principal);
- empresas com operação de atendimento ou call center;
- equipes de suporte, comercial e cobrança;
- operações administrativas e de backoffice;
- empresas com processos de validação (cadastros, fornecedores, dados);
- empresas com grande volume de chamadas;
- empresas que precisam ligar o atendimento aos sistemas internos.

## Segmentos

| Segmento | Exemplos de processo por telefone | Situação no LeadPulse |
| --- | --- | --- |
| Compras e suprimentos | Validar e qualificar fornecedores, coletar condições comerciais | **Existe hoje** (workflow de origem) |
| Dados e cadastro | Confirmar se o contato pertence à empresa, atualizar cadastro | **Existe hoje** (validação cadastral) |
| Comercial | Qualificar leads, reativar clientes, primeiro contato | Visão |
| Cobrança | Lembrar vencimento, negociar, confirmar pagamento | Visão |
| Logística | Confirmar entrega, janela de recebimento, ocorrências | Visão |
| Saúde | Confirmar consulta, lembrar preparo, remarcar | Visão |
| Serviços | Agendar, confirmar visita técnica, pesquisa pós-serviço | Visão |
| Suporte | Triagem N1, abertura de chamado, acompanhamento | Visão |

Os segmentos marcados como "Visão" ilustram a flexibilidade do motor. A landing não pode sugerir que existem templates ou clientes nesses segmentos.

**Saúde e cobrança** têm regras próprias (sigilo de dados de saúde; limites legais de contato na cobrança). Mencionar esses segmentos como possibilidade, sem prometer conformidade específica.

## Usuários e decisores

| Papel | O que procura | O que precisa ver na página |
| --- | --- | --- |
| Gestor de operações | Escala, previsibilidade, menos trabalho manual | Processo explícito, status, resultados por registro |
| Gestor de atendimento ou suporte | Qualidade consistente, cobertura, menos fila | Conversa natural, regras claras, revisão humana |
| Gestor comercial | Mais contatos qualificados, equipe focada em quem tem interesse | Qualificação, retorno comercial, interesse registrado |
| Gestor de cobrança | Volume com controle e registro | Rastreabilidade, evidência, encerramento respeitoso |
| Inovação, automação, transformação digital | Plataforma reutilizável, não um projeto por processo | Visão de workflows, simulação, integração |
| CTO ou líder de tecnologia | Arquitetura, segurança, dados, dependência de fornecedor | API, isolamento por empresa, LGPD, credenciais próprias, camadas de provedores |
| Desenvolvedor de integração | Contrato claro, autenticação, idempotência | API REST, OpenAPI, Bearer token, API de BI, página `/for-devs` |

O decisor de negócio entra pela dor operacional. O decisor técnico valida pela arquitetura e pelo controle. A página precisa servir aos dois, nessa ordem.

## Dores

- Grande volume de ligações repetitivas.
- Equipes gastando tempo com tarefas previsíveis.
- Processos telefônicos difíceis de escalar sem contratar.
- Atendimento desconectado dos sistemas: o que foi dito não chega ao CRM ou ERP.
- Baixa rastreabilidade: ninguém sabe exatamente o que foi perguntado e respondido.
- Qualidade inconsistente entre atendentes e turnos.
- Necessidade de atender fora do horário comercial.
- Pressão para reduzir custo operacional.
- Perda de contexto entre tentativas e canais.
- Dificuldade de testar um agente de IA antes de colocá-lo diante de clientes.
- Cada novo processo exige uma automação diferente, feita do zero.

## Necessidades

1. Definir o processo com clareza (o que perguntar, o que coletar, quando encerrar).
2. Executar com qualidade constante e em volume.
3. Ver o que aconteceu em cada conversa e por quê.
4. Corrigir quando a IA errar.
5. Testar antes de ir para produção.
6. Integrar com os sistemas que já usam.
7. Cumprir LGPD e manter a confiança de quem é chamado.
8. Não ficar preso a um fornecedor de tecnologia.

## Resultados esperados

Automação, escala, consistência, menos trabalho repetitivo, integração com sistemas, rastreabilidade, controle, observabilidade, flexibilidade, confiabilidade, personalização e velocidade operacional.

**Não quantificar.** Não há medição real publicada de economia de tempo, custo ou taxa de sucesso. Nada de "reduza 70% do custo" ou "10× mais ligações".

## Objeções prováveis e respostas verdadeiras

| Objeção | Resposta com base no que existe |
| --- | --- |
| "Robô ligando incomoda." | A chamada se identifica como automatizada; a recusa é registrada e respeitada. |
| "E se a IA entender errado?" | Cada resultado tem evidência (pergunta, resposta, transcrição) e pode ser revisado e corrigido por uma pessoa. |
| "Como sei que funciona antes de ligar para clientes?" | O agente é testado em simulações IA × IA com cenários e avaliação automática. |
| "E os dados?" | Base legal, finalidade e retenção por empresa; anonimização; credenciais cifradas; isolamento entre empresas. |
| "Fico preso a um fornecedor?" | Hoje a empresa usa as próprias contas Twilio e OpenAI. A arquitetura caminha para provedores intercambiáveis (visão). |
| "Integra com meu sistema?" | Hoje, por API REST (envio de lotes, resultados e evidências) e API de BI. Ações durante a conversa são visão. |

## Linguagem adequada

**Usar**: processo, workflow, etapa, conversa, operação, resultado, evidência, revisão, integração, controle, escala, simulação, avaliação.

**Evitar**: jargão de modelo (VAD, tokens, prompt, embeddings) no topo da página; linguagem acadêmica (TCC, hipótese, experimento, prova de conceito) em qualquer parte voltada a clientes; promessas absolutas ("sempre", "100%", "sem erros"); "substitua sua equipe"; antropomorfização ("nossa IA pensa como um humano").

Tom: direto, adulto, técnico quando precisa, sem euforia. Frases curtas. Português do Brasil.
