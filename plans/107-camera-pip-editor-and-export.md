# Plan 107: Exibir, editar e exportar a câmera PiP no Video Editor

> **Instruções para o executor:** execute depois do plano 106. O input de
> câmera já deve ser uma track identificável; este plano não deve descobrir
> devices, pedir TCC ou escrever frames. Entregue uma composição screen + camera
> com preview e export WYSIWYG, mantendo o caminho screen-only atual intacto.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat be4b4fef..HEAD -- Notinhas/Features/VideoEditor Notinhas/Services/Capture/RecordingMetadata.swift Notinhas/Features/History Notinhas/Features/QuickAccess NotinhasTests/Features/VideoEditor NotinhasTests/Services/Capture/RecordingMetadataStoreTests.swift`
>
> Use `.worktrees/camera-pip-editor-export` e branch
> `camera-pip-editor-export`. Merge/push não são autorizados por este plano.

## Status

- **Priority:** P1
- **Effort:** L
- **Risk:** HIGH
- **Depends on**: Plano 106; plano 104 para resultado/recuperação do writer
- **Category:** feature / architecture / performance
- **Planned at**: commit `be4b4fef` after local integration of Plans 104–106, 2026-08-23
- **Finding ID:** `camera-pip-editor-export`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem autorização explícita

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `High/Full`
- **Parallelizable:** não com planos 105 ou 108 que editem
  `VideoEditorState`, `VideoEditorExporter` ou `VideoEditorZoomCompositor`
- **Reviewer required:** sim; compositor multi-track, AVPlayer sync, geometry,
  export/save semantics e regressão do fast path
- **Rationale:** o editor atual seleciona uma única video track e o compositor
  recebe um único `trackID`; forçar um segundo vídeo por special cases teria
  risco alto de omitir a camera, duplicar pixels ou quebrar zoom/background.
- **Escalate when:** a composição multi-track não puder manter screen-only
  byte/behavior-compatible; a saída exportada exigir preservar masters
  separados; ou a preview não puder sincronizar sem polling contínuo pesado.

## Why this matters

Capturar uma camera sem permitir que o usuário veja o resultado no editor cria
uma feature “gravou, mas não sei se ficou boa”. O PiP precisa aparecer no
playback, sobreviver a trim/zoom/background e sair no arquivo final somente
quando o usuário o vê no preview.

O limite é deliberado: um único overlay, posição em presets, três tamanhos,
toggle visível e canto arredondado. Sem keyframes, múltiplas câmeras, efeitos
faciais ou layout authoring genérico. A referência de comportamento é o
[Screendrop](https://github.com/fayazara/Screendrop); a implementação é própria
e segue o produto capture → handoff.

## Current state

- `VideoEditorState.loadMetadata()` carrega duração, tamanho da primeira video
  track e roles de áudio. Não resolve screen/camera por role.
- `VideoEditorState` mantém trim, speed, zoom, background e export settings;
  `hasUnsavedChanges` e `markAsSaved()` cobrem esses campos, não layout de
  camera.
- `VideoEditorZoomCompositor.createVideoComposition()` em torno de
  `VideoEditorZoomCompositor.swift:76–107` cria uma instruction com um
  `trackID`; `requiredSourceTrackIDs` devolve um único ID.
- `ZoomVideoCompositorClass.processRequest()` recebe um único
  `sourceFrame(byTrackID:)`, aplica zoom/background e devolve um pixel buffer.
- `VideoEditorExporter.exportTrimmed()` usa export standard quando não há
  efeitos; export zoom/composition quando há zoom, background, audio custom ou
  speed. Uma camera ativa deve forçar composition, mas o caminho sem camera
  deve permanecer o mesmo.
- `ZoomableVideoPlayerSection` coloca `VideoPlayerSection(state.player)` em um
  ZStack, aplica zoom ao vídeo e já oferece uma superfície para overlay de
  indicação. Um segundo `AVPlayer`/`AVPlayerLayer` de camera ainda não existe.
- `VideoEditorWindowController` concentra Save As/Replace Original e chama o
  exporter; não é necessário criar um fluxo de save novo.
- O plano 106 adiciona `RecordingVideoSourceTrack`/role e identifica o asset
  final. Gravações antigas sem esses campos são screen-only por default.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Export settings | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorExportSettingsTests` | exit 0 |
| Zoom/compositor | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorZoomAndAutoFocusTests` | exit 0 |
| State/time | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorSpeedTimeMapTests` | exit 0 |
| Metadata | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Format/lint | `make format-check && make lint-changed` | exit 0 |
| Build | `make build-video` | exit 0 |
| Tests | `make test-video` | exit 0 |
| Agent gate | `make agent-check` | exit 0 ou baseline explícito |
| Verify map | `./scripts/verify-local.sh --base be4b4fef --full --plan-only --strict` | superfície coberta |

## Suggested toolkit

- `AVMutableComposition` para criar um item de preview com somente a camera
  track; `AVPlayerLayer`/`NSViewRepresentable` para não renderizar frames
  manualmente a cada tick.
- `AVVideoCompositionInstructionProtocol` com dois `requiredSourceTrackIDs`
  quando camera está presente; preservar uma instruction/fast path de um track
  para gravações antigas.
- Core Image + `CIImage.composited(over:)` e o `CIContext`/pixel buffer pool já
  usado pelo compositor; reutilizar máscara arredondada existente ou extrair
  helper concreto, sem biblioteca de layout/encoding.
- `VideoEditorExportLayout.aspectFitRect` e um novo model puro de layout
  normalizado. O mesmo cálculo deve ser usado pelo preview e pelo compositor.
- `@Published`/Combine existentes para state; não adicionar um timer global
  para “sincronizar” dois players.

## Scope

**In scope:**

- `Notinhas/Features/VideoEditor/VideoEditorState.swift`
- `Notinhas/Features/VideoEditor/Models/VideoEditorCameraOverlayLayout.swift`
  ou nome equivalente concreto
- `Notinhas/Features/VideoEditor/Services/VideoEditorZoomCompositor.swift`
- `Notinhas/Features/VideoEditor/Services/VideoEditorExporter.swift`
- `Notinhas/Features/VideoEditor/Components/VideoEditorZoomPreviewOverlay.swift`
  e/ou um wrapper AppKit de preview de camera
- `Notinhas/Features/VideoEditor/Components/VideoEditorRightSidebar.swift` ou
  um componente de inspector pequeno
- `Notinhas/Features/VideoEditor/VideoEditorMainView.swift`, toolbar e
  `VideoEditorWindowController` somente para wiring
- `Notinhas/Services/Capture/RecordingMetadata.swift` somente se a resolução
  de role/derivative exigir um campo já não entregue pelo plano 106
- localização e acessibilidade de Camera/PiP
- testes em `NotinhasTests/Features/VideoEditor/` e metadata/composition tests
- `docs/VIDEO_EDITOR.md` e `docs/RECORDING.md`

**Out of scope:**

- captura/TCC/device discovery (plano 106)
- câmera como áudio, múltiplas cameras ou source switching durante playback
- keyframes de layout, animação de PiP, auto-follow de rosto, blur/background
  removal, filtros, chroma key ou transcrição
- GIF camera export; GIF continua screen-only/fluxo existente
- nova biblioteca, FFmpeg, Metal renderer separado ou export de vídeo ao vivo
- reconstruir todo `VideoEditorState` ou substituir o compositor existente

## Git workflow

1. Crie `.worktrees/camera-pip-editor-export` após confirmar os contratos dos
   planos 104 e 106.
2. Faça commits separados para model/track resolution, preview/composition e
   export/tests.
3. Serialize com qualquer plano que toque `VideoEditorExporter` ou
   `VideoEditorZoomCompositor`; não integre branches em paralelo.
4. Deixe branch/worktree para revisão; não faça merge/push.

## Steps

### Step 1: Resolver tracks por role sem adivinhar imports

Adicione uma resolução concreta:

- `screenVideoTrack`: role `.screen`, ou primeira track somente quando o
  metadata antigo não declara camera;
- `cameraVideoTrack`: role `.camera` somente quando metadata identifica a
  track e ela existe no asset;
- se metadata declara camera mas o ID não existe, marque estado degradado e
  mantenha screen-only; não escolha silenciosamente a segunda track de um vídeo
  externo não produzido pelo Notinhas.

Expose no state `hasCameraTrack`, dimensions/transform/mirror e um asset/player
  de camera quando possível. Trate GIF como sem camera. Load async deve validar
  tracks antes de publicar estado para a UI.

**Verify:** testes de asset screen-only, asset com roles, metadata antiga,
track ID ausente e múltiplas tracks externas.

### Step 2: Criar o model puro de layout PiP

Defina um model `Codable`, `Equatable` e pequeno, por exemplo:

- `isVisible: Bool`;
- `position: topLeading | topTrailing | bottomLeading | bottomTrailing`;
- `size: small | medium | large`;
- `cornerRadius`/shape somente se o MVP realmente precisar; default rounded
  rect, sem um editor de shape.

O model deve calcular `CGRect` normalizado em coordenadas top-left e depois o
  frame em pixels/points de um canvas final. Regras:

- default `bottomTrailing` com margem interna previsível;
- tamanhos limitados para não cobrir o handoff inteiro;
- clamp do rect para dentro do canvas;
- aspect-fit da camera dentro do rect, sem esticar;
- mirror somente se metadata do capture disser que a camera foi espelhada;
- uma fonte de verdade para preview e export.

Não use posição arbitrária armazenada em pixels: export size, retina e preset
de aspect ratio devem produzir o mesmo PiP relativo.

**Verify:** testes puros para cada preset, canvas portrait/landscape, camera
portrait/landscape, clamp e mirror.

### Step 3: Integrar layout ao state/inspector e dirty state

Adicione `@Published var cameraOverlayLayout` somente quando a track existir,
com default determinístico. Inclua o layout no `hasUnsavedChanges`,
`markAsSaved()` e undo policy apenas se houver uma ação concreta; não invente
uma pilha de undo para cada mudança de Picker.

No inspector/side bar:

- toggle **Mostrar câmera**;
- Picker de quatro posições;
- Picker de três tamanhos;
- preview do estado atual;
- controles escondidos/disabled quando não há camera track.

Não ofereça drag/resize livre nesta primeira entrega. Se testes de usabilidade
mostrarem que presets não bastam, abra um plano posterior em vez de vazar
geometria arbitrária para o recipe.

Localize títulos, descriptions, hints e accessibility values. O termo “camera”
deve ser distinguido de “Smart Camera” do zoom virtual.

**Verify:** state tests para toggle/presets/dirty state e inspeção visual da
sidebar em light/dark, sem camera e com camera.

### Step 4: Construir preview sincronizado sem duplicar o áudio

Crie um preview de camera somente quando `hasCameraTrack`:

1. construa uma `AVMutableComposition` com a camera video track, sem audio;
2. crie um `AVPlayer`/`AVPlayerLayer` para essa composição;
3. coloque a layer no ZStack do `ZoomableVideoPlayerSection` depois da tela,
   usando o rect do mesmo canvas que o preview principal calcula;
4. quando `currentTime` mudar por scrub/step, faça seek do camera player com
   tolerância zero/pequena;
5. quando `isPlaying` mudar, pause/play e use o mesmo rate quando speed map
   estiver ativo; camera não deve emitir som;
6. em close/deinit, remova observers e libere player/composition.

O overlay fica no canvas final e não recebe o `scaleEffect` do zoom da tela;
assim o PiP permanece fixo enquanto o conteúdo da tela aproxima. Se a decisão
visual for outra, codifique-a no model e teste preview/export juntos.

Não use `AVAssetImageGenerator` a cada frame de playback. Um pequeno resync em
scrub/seek é aceitável; polling permanente não é.

**Verify:** teste de estado de sync e manual play/pause/scrub/trim com camera,
incluindo speed segment; screen-only preview não muda.

### Step 5: Expandir o compositor para dois inputs com fast path preservado

Estenda `ZoomVideoCompositionInstruction` para carregar `screenTrackID`,
`cameraTrackID?`, layout, mirror e render size. Mantenha initializer/behavior
compatível para screen-only.

- `requiredSourceTrackIDs` deve conter um ou dois IDs, sem duplicidade.
- `processRequest` obtém a screen frame obrigatória e trata camera frame como
  opcional quando a track foi declarada.
- aplique o pipeline atual de zoom/background à screen primeiro.
- componha a camera sobre o canvas final no rect calculado, com aspect-fit,
  mirror e máscara arredondada; preserve alpha/clear canvas corretamente.
- se a camera frame faltar em um instante, devolva a base screen frame e logue
  uma ocorrência amostrada; não falhe todas as exportações por um gap opcional.
- mantenha o pass-through atual quando não há zoom/background/canvas fit e não
  há camera; esse fast path deve ser idêntico ao de gravações antigas.
- não aloque um CGContext/máscara nova em todo frame se o render context/cache
  existente puder ser reutilizado; meça antes de otimizar mais.

**Verify:** composição screen-only, camera-only ausente, dois tracks, mirror,
rounded mask e missing camera frame. Use IDs reais do asset, não índice de
array.

### Step 6: Forçar composição somente quando necessário e preservar export/save

No `VideoEditorExporter`:

- inclua `state.hasCameraTrack && state.cameraOverlayLayout.isVisible` na
  decisão de composição;
- mantenha `exportStandard` atual para arquivos sem camera;
- em composition, use a screen track correta e inclua camera track somente se a
  resolução por role passou;
- preserve trim, speed map, zoom, background, dimensions, audio mix e progress;
- mantenha camera fora do audio mix;
- se camera estiver hidden, permita export screen-only e não carregue a segunda
  video track na instruction;
- se camera foi declarada mas está inválida, escolha screen-only com feedback
  de warning ou falha explícita conforme o resultado do plano 106; não entregue
  um arquivo silenciosamente sem a camera que o usuário marcou como visível.

`Save As`, `Replace Original`, temp capture e refresh de thumbnail continuam
usando `VideoEditorWindowController`. Depois de exportar uma composição baked,
valide se o output tem uma video track renderizada; não carregue metadata de
camera como se ela ainda fosse editável se o export já achatou o PiP. O plano
108 tratará persistência de recipe/master quando isso for necessário.

**Verify:** export standard screen-only, export com camera sem efeitos, export
com camera+zoom/background/speed, mute/custom audio, Save As, Replace Original,
output temp e reabertura por History/Quick Access.

### Step 7: Testar, documentar e fazer gate visual

Atualize docs com:

- camera track fica separada durante edição;
- layout MVP é preset/rounded, sem animação;
- export atual pode achatar o overlay, como já faz com zoom/background;
- fallback screen-only e limites de GIF.

Rode testes focados, build/test Video, format, lint, agent-check e verify map.
Faça review centrado em `requiredSourceTrackIDs`, `sourceFrame(byTrackID:)`,
geometria top-left/bottom-left e estado de player.

**Verify:** nenhum log de fallback esconde uma falha de composição recorrente;
manual gate registra screenshots/recording do editor e export final.

## Test plan

### XCTest obrigatório

- `CameraOverlayLayoutTests`: rects, presets, clamp, aspect-fit, mirror.
- `VideoEditorState`/track resolution tests: old metadata, role metadata,
  invalid ID, hidden/visible, dirty state.
- `VideoEditorZoomAndAutoFocusTests` ou arquivo novo: instruction one/two
  track IDs e preservação do zoom screen-only.
- composição sintética de dois video tracks: camera overlay em posição,
  tamanho, máscara e frame ausente sem crash.
- export settings/audio tests: camera não entra no audio mix e a decisão de
  composition é correta.
- preview sync tests sem wall-clock; teste state machine de play/pause/scrub.

### Manual obrigatório depois da integração

1. Abra gravação de tela + camera real; compare preview com export em
   bottom-right/small.
2. Alterne quatro posições e três tamanhos; verifique que o PiP não é cortado
   em canvas 16:9, 9:16 e 1:1.
3. Ative zoom, background/padding, trim e speed; confira que screen e camera
   seguem a mesma duração e que o PiP permanece no canvas definido.
4. Desative camera e exporte; compare com o comportamento anterior de
   screen-only.
5. Use Save As/Replace e reabra por Quick Access/History; confirme ausência de
   crash, thumbnail válida e output compatível.
6. Teste camera ausente/metadata inválida e confirme feedback/fallback definido.
7. Capture screenshots ou uma gravação curta do editor/export para o handoff
   conforme as regras do projeto.

## Done criteria

- [ ] Track screen/camera é resolvida por role/ID, sem adivinhação para vídeos
      externos.
- [ ] PiP tem model normalizado único usado por preview/export.
- [ ] Inspector oferece visible + posição + tamanho, com copy/a11y localizado.
- [ ] Preview acompanha play/pause/scrub/trim/speed sem player de áudio extra.
- [ ] Compositor usa dois source IDs somente quando necessário e mantém o
      fast path screen-only.
- [ ] Export inclui PiP quando visível e não altera áudio; hidden produz
      screen-only.
- [ ] Missing camera frame não corrompe export; falha relevante é explícita.
- [ ] Save As/Replace/History/Quick Access continuam funcionando; outputs
      baked não são tratados como source camera editável por engano.
- [ ] GIF e scheme padrão permanecem fora do recurso.
- [ ] Testes, build/test Video, format, lint, agent-check e verify local passam
      ou registram baseline exato.
- [ ] Gate manual e evidência visual foram registrados.

## STOP conditions

- O compositor multi-track altera export screen-only ou exige duplicar o
  pipeline inteiro para uma camera invisível.
- Preview e export usam geometrias diferentes, especialmente em portrait,
  padding, retina ou preferredTransform.
- A camera é renderizada com um timer/frame extractor por frame ou introduz
  backlog perceptível no MainActor.
- AVAssetExportSession descarta camera ou áudio sem que o resultado seja
  detectado antes de publicar o arquivo final.
- Save As/Replace torna impossível distinguir master multi-track de derivative
  baked sem uma decisão no plano 108.
- O resultado exige drag/resize/keyframes para parecer útil; pare e proponha
  uma extensão separada, não aumente o MVP silenciosamente.
- Um gate determinístico falha duas vezes após correção razoável.

## External-state addendum

- **Authority:** durante edição, asset multi-track + `RecordingMetadata` são a
  autoridade; após export, o arquivo de saída é a autoridade visual e seu
  metadata deve refletir se a camera continua editável ou foi baked.
- **Identity:** track IDs resolvidos por role, source URL/bookmark e output URL;
  posição/tamanho são recipe state, não identidade de track.
- **Scope:** somente source aberto no editor, output escolhido por Save As/
  Replace/temp e metadata associado por APIs existentes.
- **Preflight:** validar source tracks, metadata, output access, render size,
  camera layout clamped e audio roles antes de iniciar export.
- **Idempotency:** um export em andamento tem um output temporário único;
  callback tardio não deve publicar thumbnail/metadata de outro export.
- **Failure:** erro de camera/composition não sobrescreve original; Save As
  preserva source; Replace só remove/substitui dentro do contrato atual depois
  de output validado.
- **Concurrency:** preview seek, player teardown e export devem tolerar close;
  não manter `AVPlayerLayer`/CI resources vivos após a janela fechar.
- **Destructive actions:** Replace Original conserva o comportamento e a
  confirmação atuais; não expandir deleção para masters/metadata sem plano
  explícito.

### High-risk traceability

| Invariante | Implementação | Evidência |
| --- | --- | --- |
| role correto não é índice | resolver track ID via metadata | old/new/missing-ID tests |
| preview = export | `CameraOverlayLayout.frame(in:)` compartilhado | layout tests + manual comparison |
| camera não altera screen-only | instruction/compositor fast path | existing export tests + regression export |
| áudio não é duplicado | camera input vídeo-only + audio mix existente | audio export tests |
| output inválido não publica | validação após export antes de Save/thumbnail | export integration test + manual Save As |

## Maintenance notes

- A camera PiP deve continuar sendo uma camada de handoff; não use este plano
  como justificativa para teleprompter, streaming ou um compositor genérico.
- O layout em presets é uma simplificação deliberada. O plano 108 pode
  persistir o recipe; drag/resize/keyframes continuam fora até evidência de
  necessidade.
- O maior risco técnico está no custom compositor, não na SwiftUI sidebar.
  Reviewers devem começar por `requiredSourceTrackIDs` e pelo frame request.
- Se o custo de composição for alto, mantenha o export screen-only rápido e
  meça somente o caminho com camera; não otimize por especulação.
