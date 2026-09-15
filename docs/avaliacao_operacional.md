# Avaliação Operacional do LeadPulse

Este documento define como medir o desempenho do processo sem preencher resultados artificiais. Os indicadores devem ser gerados a partir de lotes reais exportados pela tela de Validação.

## Objetivo

Comparar o processo manual de confirmação de telefones e fornecedores com o fluxo automatizado do LeadPulse, medindo cobertura, taxa de confirmação, tempo médio de chamada, retrabalho e acurácia quando houver uma base previamente rotulada.

## Base de Referência

- O arquivo `docs/base_rotulada_experimento.csv` serve como modelo de planilha rotulada.
- Cada linha pode trazer `resultado_esperado`, `expected_result`, `resultado_manual`, `classificacao_manual` ou `status_manual`.
- Para medir tempo manual, use `manual_validation_seconds` ou `tempo_manual_segundos`.
- O SaaS mantém esses rótulos apenas em `import_metadata.reference_labels`.
- O rótulo e o tempo manual não são enviados para a API, evitando influenciar a classificação automatizada.
- Classes disponíveis: `qualified_supplier`, `wrong_company`, `does_not_supply_segment`, `not_interested`, `invalid_phone`, `inconclusive`, `not_answered` e `privacy_refusal`.

## Métricas

- Cobertura: registros retornados pela API divididos pelo total importado.
- Taxa de confirmação: registros confirmados divididos pelos registros retornados.
- Tempo médio: média de `duration_seconds` das tentativas de chamada.
- Retrabalho: registros com mais de uma tentativa divididos pelos registros retornados.
- Acurácia rotulada: resultados automáticos iguais ao rótulo manual divididos pelo total rotulado.
- Redução estimada de tempo: diferença entre o tempo manual médio e o automatizado médio dividida pelo tempo manual médio.

## Comparação Manual e Automatizada

1. Selecionar uma amostra autorizada com telefone e resultado manual conhecido.
2. Medir o tempo manual e registrar `expected_result` e `manual_validation_seconds`.
3. Importar o mesmo lote pela tela de Validação.
4. Executar a validação automatizada.
5. Revisar transcrições e evidências na Auditoria.
6. Exportar os resultados em XLSX.
7. Comparar tempo, cobertura, taxa de confirmação, retrabalho e acurácia.

## Pendências Operacionais

- Executar a comparação com uma base real autorizada; o CSV é apenas um modelo.
- Registrar data, ambiente, provedor de voz e tamanho da amostra.
- Configurar a agenda de revalidação conforme a necessidade da operação.
- Consumir endpoints públicos com o Bearer token emitido pelo SaaS nas integrações externas.
