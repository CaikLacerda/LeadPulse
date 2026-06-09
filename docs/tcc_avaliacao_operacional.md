# Avaliação Operacional do LeadPulse

Este documento registra o desenho de avaliação acadêmica sem preencher resultados artificiais. Os números finais devem ser gerados a partir dos lotes reais exportados pelo relatório de validação na tela de Validação.

## Objetivo

Comparar o processo manual de confirmação de telefones e fornecedores com o fluxo automatizado do LeadPulse, medindo cobertura, taxa de confirmação, tempo médio de chamada, retrabalho e acurácia quando houver base previamente rotulada.

## Base de Referência

- O arquivo `docs/tcc_base_rotulada_experimento.csv` serve como modelo de planilha rotulada para o experimento de fornecedores.
- Cada linha pode trazer `resultado_esperado`, `expected_result`, `resultado_manual`, `classificacao_manual` ou `status_manual`.
- Para medir tempo manual, use `manual_validation_seconds` ou `tempo_manual_segundos`.
- O SaaS mantém esses rótulos apenas em `import_metadata.reference_labels`.
- O rótulo e o tempo manual não são enviados para a API, para evitar vazamento da resposta esperada durante a validação.
- Classes recomendadas para a avaliação acadêmica: `qualified_supplier`, `wrong_company`, `does_not_supply_segment`, `not_interested`, `invalid_phone`, `inconclusive`, `not_answered` e `privacy_refusal`.

## Métricas

- Cobertura: registros retornados pela API divididos pelo total importado.
- Taxa de confirmação: registros confirmados divididos pelos registros retornados.
- Tempo médio: média de `duration_seconds` das tentativas de chamada.
- Retrabalho: registros com mais de uma tentativa de chamada divididos pelos registros retornados.
- Acurácia rotulada: registros em que o resultado automático coincide com o rótulo manual dividido pelo total rotulado.
- Redução estimada de tempo: diferença entre tempo manual médio e tempo automatizado médio dividida pelo tempo manual médio.

## Experimento Manual vs Automatizado

1. Selecionar uma amostra de registros com telefone e resultado manual conhecido.
2. Medir o tempo de validação manual e registrar `expected_result` e `manual_validation_seconds` na planilha.
3. Importar o mesmo lote no LeadPulse pela tela de Validação.
4. Executar a validação automatizada pela API.
5. Revisar as transcrições/evidências na tela de Auditoria e corrigir classificações quando necessário.
6. Exportar o relatório em XLSX pelo botão "Relatório de validação".
7. Comparar tempo, cobertura, taxa de confirmação, retrabalho e acurácia.
8. Transferir os indicadores finais para a seção de resultados do artigo, sempre informando a data do experimento e o tamanho da amostra.

## Pontos Pendentes

- Executar o experimento com uma base real autorizada, porque o arquivo CSV deste diretório é apenas um modelo operacional.
- Registrar data, ambiente, provedor de voz e tamanho da amostra usados no experimento.
- A revalidação periódica ainda depende de agenda operacional ou endpoint dedicado.
- A integração ERP deve consumir os endpoints públicos com bearer token emitido no SaaS.
