# Vídeo do hero

## Arquivo

`hero-video-loop.mp4`, cópia idêntica de `LeadPulse/hero-video-loop.mp4`, indicado pelo usuário como vídeo da landing.

| Propriedade | Valor (medido com `ffprobe`) |
| --- | --- |
| Resolução | 1920 × 1080 (16:9) |
| Duração | 8,0 s |
| Quadros | 30 fps |
| Codec | H.264 |
| Áudio | nenhuma faixa de áudio |
| Tamanho | 22,7 MB (~22,7 Mbit/s) |

## O que o vídeo mostra

Fundo grafite escuro, quase preto, com textura sutil e sem texto.

- **Esquerda**: forma de onda vertical em azul e ciano, com fios entrelaçados que oscilam. Representa a **voz e a conversa**.
- **Direita**: grafo de workflow com nós (círculos, losango, quadrado, hexágono) ligados por linhas finas. Um caminho se acende progressivamente, da entrada à saída. Representa o **workflow e a automação**.
- **Centro**: área limpa, reservada para headline, subtítulo e CTA.

A composição traduz a mensagem central: **a conversa à esquerda vira processo à direita**.

`frames/` traz 4 quadros (0,5 s, 2,5 s, 4,5 s, 6,5 s) extraídos da cópia com `ffmpeg`, para quem não consegue assistir ao vídeo. **Servem só para análise.** Não são poster de produção.

## Função na landing

Fundo do hero. O conteúdo fica centralizado sobre a área limpa.

Implementação futura provável (**não implementar nesta etapa**):

- atributos `autoplay`, `muted`, `loop` e `playsinline` (sem `muted`, navegadores bloqueiam o autoplay; sem `playsinline`, o iOS abre em tela cheia);
- `poster` com um quadro estático, exibido até o vídeo carregar;
- com `prefers-reduced-motion: reduce`, mostrar só o poster;
- camada de contraste entre o vídeo e o texto, garantindo WCAG AA;
- `preload` controlado, para o vídeo não competir com o conteúdo principal.

## Pontos de atenção para o planejamento

1. **Peso**: 22,7 MB é pesado para o primeiro carregamento. Prever versões comprimidas (por exemplo MP4/H.264 e WebM/AV1 com bitrate menor, e uma versão menor para mobile) e o poster. Gerar esses derivados é uma etapa futura e deve preservar este arquivo.
2. **Mobile**: em telas estreitas, recortar 16:9 pelo centro elimina a onda e o grafo, que estão nas bordas. O Astra deve propor o tratamento: outro enquadramento, poster ou vídeo vertical futuro.
3. **Loop**: confirmar visualmente se o último quadro emenda no primeiro sem salto.
4. **Ritmo**: o caminho do grafo acende ao longo dos 8 s. O texto do hero não deve competir com esse movimento.

## Regras

- Não editar, recortar, recomprimir nem substituir `hero-video-loop.mp4` sem necessidade e sem aprovação.
- Derivados (poster, versões comprimidas) devem ter nomes próprios, como `hero-video-loop-1280.webm` ou `hero-poster.jpg`, e ficar ao lado do original.
- O original continua em `LeadPulse/hero-video-loop.mp4`.
