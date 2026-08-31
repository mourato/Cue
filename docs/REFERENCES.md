# Referências de produto

Benchmark de ferramentas nativas de captura para orientar o fluxo principal do
Notinhas: **capturar → anotar com pins/notas → copiar/exportar**.

Esta é uma referência de produto, não uma lista de requisitos. As observações
foram levantadas dos READMEs dos projetos em 10/08/2026; o Screendrop foi
adicionado em 23/08/2026 a partir do README e das fontes de gravação. Tudo
deve ser validado manualmente antes de virar plano ou promessa de comportamento.

## Matriz rápida

| Projeto | Classificação | O que vale estudar | Oportunidade para o Notinhas | Licença / decisão | Clone |
| --- | --- | --- | --- | --- | --- |
| [macshot](https://github.com/sw33tLie/macshot) | UI/UX; mesmo domínio | Captura e anotação no mesmo fluxo; snap de janela/bordas; presets de proporção/tamanho; seleção de objeto para editar; histórico com anotações editáveis; beautify; OCR/redação automática. | Tornar seleção e edição mais precisas; presets de captura; reabrir uma captura anotada sem perder a estrutura; avaliar beautify como saída opcional para handoff. | [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.html). Apenas inspiração e reimplementação independente; não copiar código/assets sem revisar as obrigações de copyleft. | Não; consulta remota |
| [BetterShot](https://github.com/KartikLabhshetwar/better-shot) | UI/UX; mesmo domínio | Preview flutuante com clique para editar; drag-to-app; defaults de beautify com preview; editor com atalhos de uma tecla; status de gravação compacto; histórico separado e toasts de confirmação. | Reduzir o caminho entre captura e destino; deixar ações do Quick Access mais óbvias; melhorar feedback de copiar/salvar/OCR; estudar defaults visuais persistentes. | [BSD-3-Clause](https://opensource.org/license/bsd-3-clause). Inspiração; eventual reutilização só com avisos e atribuição exigidos pela licença. | Não; consulta remota |
| [Capso](https://github.com/lzhgus/Capso) | UI/UX; mesmo domínio; engenharia | HUD all-in-one com modos claros; presets de proporção/tamanho; drag handle no preview; OCR visual e tradução; histórico persistente com retenção; PiP de webcam; setup guiado de R2. | Melhorar descoberta dos modos; estudar OCR orientado a blocos; tornar retenção/histórico mais previsíveis; avaliar tradução e compartilhamento BYO-storage apenas se servirem ao handoff. | [BSL 1.1](https://mariadb.com/bsl11/). Não copiar nem adaptar para um produto concorrente; usar somente como referência de comportamento até a conversão indicada pelo projeto. | Não; consulta remota |
| [Screendrop](https://github.com/fayazara/Screendrop) | UI/UX; mesmo domínio; engenharia | Preview stack com ações configuráveis; gravação nativa de tela com câmera, microfone e áudio do sistema; sessão não destrutiva com masters e metadados separados; cursor/cliques/teclas editáveis; writer fragmentado com backpressure e recuperação; Studio com timeline, zoom, transcrição e presets. | Adotar primeiro as práticas de gravação que protegem o trabalho: sessão recuperável, falha parcial preservada, fontes separadas e render cacheado. Só considerar recursos de Studio quando produzirem um handoff visual mais claro, não para virar uma alternativa genérica ao Loom. | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Inspiração e reimplementação independente; a licença permite reutilização, mas não há necessidade de copiar código ou assets. | Sim; consulta local |

O resultado observado de aproximadamente **8 MB** não é tratado como uma meta
universal: tamanho depende de duração, resolução, taxa de quadros, codec,
áudio e de ser um master ou um export. Qualquer comparação de compressão deve
medir esses parâmetros em conjunto.

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

Gravação avançada além dos planos registrados, tradução, upload genérico e uma
arquitetura de pacotes inspirada no Capso não entram automaticamente no
roadmap. A câmera PiP foi promovida explicitamente para o roadmap como uma
camada opcional de handoff; seu limite está definido nos planos 106–107.

## Regras de uso

- Os links acima são as fontes canônicas; o benchmark observa comportamento,
  não importa código ou assets.
- O catálogo operacional correspondente, com classificação, licença/versionamento,
  decisão de reutilização, estado de clone e touchpoints, fica em
  `.agents/overlays/reference-apps.md`.
- Antes de adotar qualquer implementação, conferir a licença da versão exata,
  os avisos de terceiros e os touchpoints no Notinhas; consulta remota não
  autoriza copiar código ou assets.
- Toda decisão derivada deste documento deve apontar para o projeto de origem e
  para a superfície afetada em `Features/Notinhas`, `Annotate`, `QuickAccess`
  ou `History`.
