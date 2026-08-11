# Referências de produto

Benchmark de ferramentas nativas de captura para orientar o fluxo principal do
Notinhas: **capturar → anotar com pins/notas → copiar/exportar**.

Esta é uma referência de produto, não uma lista de requisitos. As observações
foram levantadas dos READMEs dos projetos em 10/08/2026; devem ser validadas
manualmente antes de virar plano ou promessa de comportamento.

## Matriz rápida

| Projeto | O que vale estudar | Oportunidade para o Notinhas | Licença / decisão |
| --- | --- | --- | --- |
| [macshot](https://github.com/sw33tLie/macshot) | Captura e anotação no mesmo fluxo; snap de janela/bordas; presets de proporção/tamanho; seleção de objeto para editar; histórico com anotações editáveis; beautify; OCR/redação automática. | Tornar seleção e edição mais precisas; presets de captura; reabrir uma captura anotada sem perder a estrutura; avaliar beautify como saída opcional para handoff. | GPL-3.0. Apenas inspiração e reimplementação independente; não copiar código/assets sem revisar as obrigações de copyleft. |
| [BetterShot](https://github.com/KartikLabhshetwar/better-shot) | Preview flutuante com clique para editar; drag-to-app; defaults de beautify com preview; editor com atalhos de uma tecla; status de gravação compacto; histórico separado e toasts de confirmação. | Reduzir o caminho entre captura e destino; deixar ações do Quick Access mais óbvias; melhorar feedback de copiar/salvar/OCR; estudar defaults visuais persistentes. | BSD-3-Clause. Inspiração; eventual reutilização só com avisos e atribuição exigidos pela licença. |
| [Capso](https://github.com/lzhgus/Capso) | HUD all-in-one com modos claros; presets de proporção/tamanho; drag handle no preview; OCR visual e tradução; histórico persistente com retenção; PiP de webcam; setup guiado de R2. | Melhorar descoberta dos modos; estudar OCR orientado a blocos; tornar retenção/histórico mais previsíveis; avaliar tradução e compartilhamento BYO-storage apenas se servirem ao handoff. | BSL 1.1. Não copiar nem adaptar para um produto concorrente; usar somente como referência de comportamento até a conversão indicada pelo projeto. |

## Padrões priorizados

### P1 — reduzir atrito do handoff

- Preview pós-captura com ações primárias mais explícitas: **copiar**, **anotar**,
  **salvar**, **arrastar para outro app** e **fixar**.
- Feedback curto e persistente o suficiente para confirmar a ação, sem tirar o
  usuário do canvas.
- Presets de proporção e tamanho para screenshots de produto, documentação e
  posts.

### P2 — aumentar precisão da anotação

- Seleção direta de uma anotação para mover, redimensionar, editar ou apagar.
- Guias/snap de alinhamento e edição posterior de uma captura já anotada.
- OCR visual para localizar blocos de texto e apoiar notas ou redação.

### P3 — saída visual opcional

- Beautify não deve entrar no caminho padrão: oferecer fundo, padding, raio e
  sombra como uma transformação opcional para apresentações.
- Redação de PII só deve ser considerada com confirmação explícita e revisão
  visual antes da cópia/exportação.

## Fora do foco atual

Gravação avançada, webcam PiP, tradução, upload genérico e uma arquitetura de
pacotes inspirada no Capso não entram automaticamente no roadmap. Só devem ser
promovidos se melhorarem diretamente o handoff visual e houver uma necessidade
concreta no produto.

## Regras de uso

- Os links acima são as fontes canônicas; o benchmark observa comportamento,
  não importa código ou assets.
- Antes de adotar qualquer implementação, conferir a licença da versão exata,
  os avisos de terceiros e os touchpoints no Notinhas.
- Toda decisão derivada deste documento deve apontar para o projeto de origem e
  para a superfície afetada em `Features/Notinhas`, `Annotate`, `QuickAccess`
  ou `History`.
