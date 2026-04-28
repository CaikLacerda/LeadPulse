# Guia rápido das telas do LeadPulse

## Objetivo

Este material é para quem não programa e quer entender, de forma rápida, o que cada tela do sistema faz no dia a dia.

O LeadPulse ajuda a organizar três etapas principais:

- encontrar fornecedores
- validar contatos por ligação
- acompanhar e exportar o resultado

## 1. Tela de Configurações

Essa área prepara a conta para operar.

Ela é dividida em quatro partes:

- Empresa
- Twilio
- OpenAI
- Token da API

### Empresa

Aqui ficam os dados principais da operação:

- nome da empresa
- nome falado pela assistente
- nome do responsável
- e-mail do responsável

Na prática, essa tela define como a operação será identificada durante as validações.

### Twilio

Aqui são configurados:

- conta de telefonia
- token da Twilio
- URL pública do webhook
- números que podem fazer as ligações

Na prática, essa tela define por quais números o sistema pode ligar.

### OpenAI

Aqui ficam:

- chave da OpenAI
- modelo de voz
- voz usada na ligação
- velocidade da fala
- instruções de estilo

Na prática, essa tela define como a assistente vai conversar.

### Token da API

Essa tela gera o token de acesso da conta.

Esse token é usado para:

- autenticar busca
- autenticar envio de lotes
- autenticar consulta de status

Resumo simples da área de Configurações:

> Sem essa parte configurada, o restante do sistema não opera direito.

## 2. Tela de Busca

A tela de Busca serve para abrir um segmento e encontrar fornecedores com telefone.

### O que o usuário informa

- segmento
- região ou cidade
- quantidade máxima
- telefone de retorno
- contato para retorno

### O que a tela faz

Depois de executar a busca, o sistema:

- salva o resultado
- remove fornecedores sem telefone
- deixa a busca registrada para consulta futura
- permite baixar a planilha
- permite transformar a busca em lote de validação de segmento

### O que o usuário vê

Na lista aparecem:

- código da busca
- segmento
- região
- data
- quantidade encontrada
- ações

### Ações disponíveis

- baixar planilha
- importar lote

Resumo simples da tela de Busca:

> Ela serve para abrir um recorte de mercado e transformar isso em uma base aproveitável para validação.

## 3. Tela de Validação

Essa é a tela principal da operação.

É onde os lotes entram, são iniciados, consultados e exportados.

### Como um lote entra nessa tela

Existem dois caminhos:

- upload de planilha
- importação vinda da Busca

### Tipos de lote

#### Validação cadastral

Usa uma planilha com dados como:

- empresa
- telefone
- CNPJ

O objetivo é confirmar se aquele telefone pertence mesmo à empresa.

#### Validação de segmento

Vem da Busca ou de planilha própria de segmento.

O objetivo é confirmar:

- se o telefone pertence à empresa
- se a empresa fornece aquele segmento
- se o contato pode receber retorno comercial

### O que aparece na tabela

Cada lote mostra:

- código
- data
- origem
- tipo
- total de registros
- válidos
- inválidos
- status

### Status mais comuns

- Pendente: lote ainda não foi iniciado
- Processando: lote foi enviado e está em andamento
- Concluído: lote terminou e já tem retorno útil
- Erro: houve falha técnica ou problema no lote

### Ações do lote

Dependendo do estado, o usuário pode:

- iniciar validação
- consultar status
- exportar resultado
- reiniciar
- excluir

Resumo simples da tela de Validação:

> É o centro da operação. Tudo que vira ligação e retorno passa por aqui.

## 4. Modal de importação de lote

Quando o usuário clica em `Novo lote`, abre um modal para importar a planilha.

### O que o usuário escolhe

- tipo do lote
- arquivo
- separador CSV, quando necessário

Se for lote de segmento, a planilha precisa estar alinhada ao fluxo de fornecedores.

### Resultado esperado

Depois da importação, o lote aparece na tabela com status `Pendente`.

## 5. Início da validação

Quando o usuário clica em `Iniciar`, o lote sai do Rails e é enviado para a API de validação.

O usuário não precisa acompanhar tecnicamente essa parte.

Para o uso diário, o importante é:

- o lote muda para `Processando`
- depois pode ser consultado
- ao final pode ser exportado

## 6. Consulta de status

O botão `Consultar status` atualiza o lote com o retorno mais recente da API.

Na prática, ele serve para:

- puxar o andamento do lote
- atualizar o status na tabela
- trazer o resultado final quando a operação já terminou

Resumo simples:

> É o botão de atualização do andamento do lote.

## 7. Exportação de resultado

Quando um lote termina, o usuário pode exportar o CSV final.

### O que normalmente sai no arquivo

No cadastral, o export mostra coisas como:

- empresa
- telefone informado
- telefone validado
- resultado da validação
- status da ligação
- observação
- data final

No segmento, o export mostra também:

- se o telefone pertence à empresa
- se fornece o segmento
- se aceita retorno comercial

Resumo simples:

> A exportação transforma o retorno técnico da operação em uma planilha utilizável pelo time.

## 8. Tela de Auditoria

A Auditoria serve para revisar o histórico das validações.

Ela é útil para:

- conferir o que aconteceu em cada lote
- ver o resultado da chamada
- abrir a transcrição do cliente
- abrir a transcrição da assistente

### O que aparece na tabela

- lote
- data e hora
- ação
- resultado
- link para ver transcrições

Resumo simples:

> A auditoria é a área de rastreabilidade e revisão da operação.

## 9. Fluxo completo de uso, de forma resumida

Um fluxo típico do sistema é:

1. configurar a conta
2. abrir uma Busca ou importar uma planilha
3. criar um lote
4. iniciar a validação
5. consultar status
6. revisar a auditoria, se necessário
7. exportar o resultado final

## 10. Frase curta para explicar o produto

Se alguém perguntar “o que o sistema faz?”, uma resposta simples é:

> O LeadPulse organiza busca, validação por ligação e retorno operacional em um único fluxo.

## 11. Frase curta para explicar as telas

Se alguém perguntar “como o usuário usa o sistema?”, uma resposta simples é:

> Primeiro a conta é configurada, depois o usuário busca ou importa contatos, envia isso para validação, acompanha o lote e no final exporta o resultado.
