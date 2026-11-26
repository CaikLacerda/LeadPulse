# Referências visuais

As referências desta pasta orientam **estrutura e acabamento**. Não são modelo para copiar. A landing do LeadPulse deve ter identidade própria.

## `landing-reference.jpg`

- **Origem**: `LeadPulse/4f51b741739f48f16b22532074a79d18.jpg`, indicada pelo usuário como referência. A cópia é idêntica ao original.
- **Formato**: JPG, 736 × 1324 px, mostrando o hero e as duas primeiras seções. A resolução é baixa: serve para estrutura, não para medir detalhes.
- **Conteúdo**: landing de um produto fictício de notas com IA ("Agex"), em tema escuro, preto e azul.

### O que observar

| Aspecto | Como aparece na referência | Uso no LeadPulse |
| --- | --- | --- |
| Hero | Headline centralizada em duas linhas, subtítulo curto, um CTA dominante | Hierarquia equivalente, sobre o vídeo do hero (o centro do vídeo é limpo para isso) |
| Produto logo após o hero | Interface grande, com leve profundidade, sobreposta ao fim do hero | Mostrar uma **tela real** do LeadPulse nessa posição |
| Navegação | Barra compacta, poucos itens, um botão de entrada | Navegação curta e objetiva |
| Ritmo | Muito espaço vertical; cada seção com um selo pequeno e um título forte | Mesmo ritmo, com tipografia sóbria |
| Seção de recursos | Grade assimétrica de cartões, cada um com um recorte de interface | Recortes de telas reais (conversa, avaliação, eventos) em vez de ilustrações |
| Profundidade | Gradientes escuros, brilho localizado, bordas finas | Usar com moderação: grafite e navy, ciano discreto |
| Tipografia | Sans-serif grande e com espaçamento fechado nos títulos; texto de apoio pequeno e claro | Escala tipográfica equivalente |

### O que não aproveitar

- O texto, o nome "Agex" e o tema "notas com IA".
- A faixa "Trusted by top brands": o LeadPulse **não tem clientes nem logos autorizados** para exibir. Nenhuma faixa de logos fictícios.
- Dashboards inventados. Os cartões da referência mostram uma interface ilustrativa; no LeadPulse, use apenas telas reais.
- Captura de e-mail como CTA principal. O fluxo comercial do LeadPulse ainda está em definição (ver `docs/CONTENT_DIRECTION.md`).
- Excesso de feixe de luz, estrelas e partículas. O azul da referência é saturado; a direção do LeadPulse é grafite, navy e ciano contido.

## `current-leadpulse-site/`

Capturas da **landing pública que já existe** no app Rails (`app/views/pages/_public_landing.html.erb`), feitas na rodada de redesign de 03/10/2026 (`docs/redesign-publico/`).

| Arquivo | Conteúdo |
| --- | --- |
| `landing-1440-hero.jpg` | Hero atual: "Encontre empresas. Valide por voz.", tema claro, tela real de Analytics ao lado |
| `landing-1440-full.jpg` | Página completa: como funciona, recursos, planos, sobre, FAQ, contato |

Estas imagens são **contexto, não referência visual**. Elas mostram o posicionamento antigo, focado em prospecção e validação de fornecedores, que a nova landing deve ampliar. Ajudam a entender:

- o que já foi comunicado publicamente;
- quais telas reais já foram usadas;
- frases que continuam corretas, como "a chamada se identifica, a recusa é respeitada e cada resultado pode ser revisado por uma pessoa";
- a seção "Planos em definição": hoje não existe preço público.

## Como adicionar novas referências

1. Salve a imagem aqui com nome descritivo (`ref-<origem>-<aspecto>.jpg`).
2. Acrescente uma seção neste README com origem, o que aproveitar e o que não aproveitar.
3. Referências de concorrentes servem para entender o mercado. Nunca copie texto, layout ou marca.
