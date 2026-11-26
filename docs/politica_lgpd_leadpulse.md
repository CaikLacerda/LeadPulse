# Política LGPD operacional do LeadPulse

Este documento descreve como a política LGPD da conta é usada dentro do LeadPulse. A ideia é manter a regra em um único lugar: a tela **Configurações > LGPD**.

## 1. Onde a política é configurada

A política padrão fica na tela de LGPD da conta. Ela define:

- perfil/permissão do usuário;
- base legal padrão;
- finalidade padrão;
- aviso falado pela IA no início da chamada;
- permissão de gravação/transcrição;
- prazo de retenção das evidências;
- comportamento em caso de recusa ou pedido de interrupção;
- controlador/responsável e e-mail administrativo.

## 2. Como a política entra nos lotes

Ao importar uma planilha, o modal não pede mais confirmação LGPD por lote. O LeadPulse usa automaticamente a política salva na conta e envia esse bloco junto do payload para a API.

Isso evita divergência entre lotes e deixa a governança em um ponto único de configuração.

## 3. Aviso falado pela IA

O campo **Aviso falado pela IA** deve ser usado para informar, de forma clara, que a ligação é automatizada e pode ser gravada/transcrita quando essa opção estiver habilitada.

Exemplo operacional:

> Esta é uma chamada automatizada para validação cadastral e comercial. A ligação poderá ser gravada e transcrita para auditoria, e você pode pedir para interromper a qualquer momento.

## 4. Base legal e finalidade

A base legal e a finalidade são registradas junto do lote para auditoria. O uso esperado no LeadPulse é validação cadastral/comercial de fornecedores, confirmação de telefone, vínculo com empresa e aderência a um segmento.

A empresa operadora da conta continua responsável por garantir que a base importada tem origem e finalidade compatíveis com a abordagem.

## 5. Retenção de áudio e transcrição

As evidências ficam vinculadas ao lote enquanto a retenção estiver ativa. Após o prazo configurado, a rotina de retenção pode anonimizar transcrições, referências de gravação e detalhes sensíveis conforme a operação permitir.

## 6. Recusa ou interrupção

Quando a opção de bloquear chamadas após recusa estiver ativa, o LeadPulse registra o número como bloqueado para novas chamadas automáticas. Isso reduz insistência indevida e preserva a trilha do motivo.

## 7. Anonimização e exclusão de evidências

O sistema permite anonimizar evidências de lotes e também tratar solicitações LGPD. A anonimização remove ou mascara transcrições, gravações e campos sensíveis, mantendo apenas o mínimo necessário para auditoria operacional.

## 8. Solicitações LGPD, terceiros e auditoria

A tela de LGPD centraliza o acesso para:

- **Solicitações LGPD**: registro e acompanhamento de pedidos relacionados a dados pessoais;
- **Operadores e terceiros**: cadastro de fornecedores ou sistemas que participam da operação;
- **Trilha de auditoria**: histórico de eventos relevantes, como importação, exportação, acesso a evidências e alterações de política.

## 9. Fluxo recomendado

1. Configurar Empresa, Twilio, OpenAI e Token.
2. Revisar a política LGPD da conta.
3. Importar ou gerar uma base de fornecedores.
4. Iniciar a validação.
5. Revisar auditoria e resultados.
6. Exportar somente o necessário.
7. Anonimizar ou reter evidências conforme a política definida.
