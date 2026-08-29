# Plan 109: Zoom automático a partir de cliques (MVP Screendrop)

> **Instruções para o executor:** leia este plano inteiro antes de editar. A
> entrega é **paridade funcional mínima** com o `ZoomCueSynthesizer` do
> Screendrop (@ `57a48dd`): cliques persistidos na metadata, segmentos de zoom
> gerados automaticamente ao abrir o editor, editáveis e regeneráveis. Não
> implemente cursor sintético, física de viewport com molas, modos de âncora
> smart/pinned nem persistência de projeto — isso fica no plano 110.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat ee55c91a..HEAD -- Notinhas/Services/Capture/RecordingMetadata.swift Notinhas/Services/Capture/RecordingMouseTracker.swift Notinhas/Services/Capture/MouseClickHighlightService.swift Notinhas/Features/Recording/RecordingCoordinator.swift Notinhas/Features/VideoEditor NotinhasTests/Services/Capture NotinhasTests/Features/VideoEditor docs/RECORDING.md docs/VIDEO_EDITOR.md`
>
> **Referência local:** `~/Documents/Projects/References/Screendrop/` @
> `57a48dd` — estudar `RecordingViewportTimeline.swift` (`ZoomCueSynthesizer`),
> `RecordingPointerCapture.swift`, `RecordingStudioModel.swift`
> (`resynthesizeZoomCues`). Reimplementação independente; não copiar código CC0
> literalmente sem revisão de atribuição.
>
> Use `.worktrees/auto-zoom-from-clicks-mvp` e branch
> `auto-zoom-from-clicks-mvp`. Merge/push não são autorizados por este plano.

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MEDIUM
- **Depends on:** planos 104–107 concluídos; serializar com qualquer plano que
  edite `RecordingMetadata`, `VideoEditorState`, `VideoEditorExporter` ou
  `VideoEditorZoomCompositor`
- **Category:** feature
- **Planned at**: commit `ee55c91a`, 2026-08-29
- **Finding ID:** `auto-zoom-from-clicks-mvp`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem
  autorização explícita

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** não com plano 110 ou qualquer plano que toque os mesmos
  arquivos de metadata/editor
- **Reviewer required:** sim; metadata versioning, timing de cliques vs mouse
  samples, geração de segmentos e regressão do editor sem cliques
- **Rationale:** o Follow Mouse já existe; o gap é captura estruturada de
  cliques + sintetizador + wiring na abertura do editor. Escopo fechado evita
  reescrever o compositor.
- **Escalate when:** cliques não puderem ser alinhados ao timeline do vídeo com
  tolerância sub-frame; gravações antigas quebrarem decode; ou a geração auto
  conflitar com segmentos manuais existentes sem política clara.

## Why this matters

Gravações de handoff visual frequentemente mostram cliques em UI. Apps como
Screendrop e Screen Studio geram zooms automaticamente nesses momentos. O
Notinhas grava posição contínua do mouse (`RecordingMouseTracker`) e permite
Follow Mouse **dentro** de segmentos manuais, mas o usuário ainda precisa
pressionar **Z** para cada zoom — atrito alto para tutoriais e demos.

O Screendrop resolve isso com `ZoomCueSynthesizer`: cada `mouse-down` vira um
`ZoomCue` com pre/post-roll, merge de cliques próximos e âncora no ponteiro.
Este plano entrega o equivalente mínimo no Notinhas sem alterar a física de
transição (ease cúbico existente) nem esconder o cursor do master.

## Current state

- `RecordingMetadata` (v6): `mouseSamples` contínuos; **sem** eventos de clique.
- `MouseClickHighlightService`: detecta cliques para overlay visual; callbacks
  não persistem tempo normalizado na metadata.
- `RecordingMouseTracker`: amostras @ `clamp(fps×2, 60, 120)` Hz; pausa/resume
  alinhados ao writer.
- `VideoEditorState.addZoom(at:)`: default `.auto` se há `mouseSamples`; sem
  auto-população na carga.
- `ZoomSegment`: `ZoomType.auto/.manual`; **sem** flag `isImplicit`.
- `VideoEditorAutoFocusEngine`: path suave dentro do segmento; não gera
  segmentos.
- Preferências de gravação: `highlightClicks`, `showCursor`; nada para auto-zoom
  no editor.

## Screendrop parity target (MVP only)

Constantes de `ZoomCueSynthesizer` a replicar:

| Parâmetro | Valor |
| --- | --- |
| `preRoll` | 0,3 s |
| `postRoll` | 2,5 s |
| `joinTolerance` | 2,5 s |
| `tailExclusion` | 1,0 s (ignorar cliques no último segundo) |
| `trailingGuard` | 0,8 s |
| `earliestStart` | 0,001 s |
| `defaultMagnification` | **1,5×** (Notinhas usa 2× hoje — alinhar no sintetizador) |

Comportamento:

- Trigger: somente `phase == .down`, coords normalizadas 0…1.
- Merge transitivo: cues com `start ≤ previous.end + joinTolerance` estendem
  `end`.
- Segmentos gerados: `zoomType == .auto`, `isImplicit == true`.
- Regenerar: substituir **apenas** segmentos implícitos; preservar manuais.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Metadata | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Mouse tracker | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/Recording/RecordingMouseTrackerTests` | exit 0 |
| Zoom/autofocus | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorZoomAndAutoFocusTests` | exit 0 |
| Sintetizador (novo) | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorZoomSegmentSynthesizerTests` | exit 0 |
| Format/lint | `make format-check && make lint-changed` | exit 0 |
| Build | `make build-video` | exit 0 |
| Tests | `make test-video` | exit 0 |
| Agent gate | `make agent-check` | exit 0 |
| Verify map | `./scripts/verify-local.sh --base ee55c91a --full --plan-only --strict` | superfície coberta |

## Scope

**In scope:**

- `Notinhas/Services/Capture/RecordingMetadata.swift` — v7: `mousePresses`
- `Notinhas/Services/Capture/RecordingMouseTracker.swift` ou novo
  `RecordingClickRecorder.swift` (preferir extensão mínima do pipeline existente)
- `Notinhas/Services/Capture/MouseClickHighlightService.swift` — compartilhar
  detecção ou receber press events do mesmo monitor
- `Notinhas/Features/Recording/RecordingCoordinator.swift` — start/stop/pause
  alinhados ao mouse tracker
- `Notinhas/Features/VideoEditor/Services/VideoEditorZoomSegmentSynthesizer.swift`
  (nome concreto)
- `Notinhas/Features/VideoEditor/Models/VideoEditorZoomSegment.swift` —
  `isImplicit`
- `Notinhas/Features/VideoEditor/VideoEditorState.swift` — auto-populate,
  `resynthesizeImplicitZoomSegments()`, contagem de cliques
- `Notinhas/Features/VideoEditor/Components/VideoEditorRightSidebar.swift` ou
  inspector de zoom — contagem, toggle master, botão regenerar
- `Notinhas/Features/Preferences/` — preferência `autoGenerateZoomOnOpen`
  (default **on** para gravações Notinhas com presses)
- Localização + a11y
- Testes em `NotinhasTests/Services/Capture/` e
  `NotinhasTests/Features/VideoEditor/`
- `docs/RECORDING.md`, `docs/VIDEO_EDITOR.md`

**Out of scope (plano 110):**

- Ocultar cursor SCK e reconstruir ponteiro no export
- `ViewportTimeline` com molas @ 120 Hz, comfort widening, settle guard
- Modos `smartAnchor` / `pinnedAnchor` além do center picker manual
- Cliques/teclas como overlay editável pós-gravação (só metadata de cliques aqui)
- Timeline multi-clip (split/delete)
- Presets de estilo, reframe Fill/Fit, cache de render
- Persistência de projeto (`edit.json`); segmentos implícitos são voláteis como
  hoje até plano 110
- GIF auto-zoom (opcional: gerar se metadata existir; não bloquear MVP)

## Git workflow

1. Crie `.worktrees/auto-zoom-from-clicks-mvp` após drift check limpo.
2. Commits separados: metadata capture → sintetizador → editor wiring → UI/prefs
   → docs/tests.
3. Não integre em paralelo com plano 110.
4. Deixe branch/worktree para revisão.

## Steps

### Step 1: Modelar e persistir eventos de clique (metadata v7)

Adicionar tipos puros:

```swift
struct RecordedMousePress: Codable, Equatable {
    var time: TimeInterval
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var button: Int // 0 left, 1 right, 2 other — espelhar Screendrop
    var phase: PressPhase // .down / .up
    enum PressPhase: String, Codable { case down, up }
}
```

- Bump `RecordingMetadata.currentVersion` para **7**; decode v6 → `mousePresses = []`.
- Canonicalize em `topLeftNormalized` como mouse samples.
- `RecordingMetadataStore` tests: round-trip v7, migration v6, legacy sidecars.

**Captura:** gravar `down` e `up` dentro do retângulo de gravação, com o **mesmo
relógio** do `RecordingMouseTracker` (uptime − pausas acumuladas). Dedup de
presses duplicados em 50 ms (referência Screendrop). Pausa/resume/stop devem
pausar/resumir o recorder de cliques junto ao mouse tracker.

Integrar no `RecordingCoordinator` stop path: passes `mousePresses` para
`RecordingMetadata` save.

**Verify:** testes unitários de timing, pause, dedup, coords fora do retâculo
 ignoradas, migration.

### Step 2: Implementar `VideoEditorZoomSegmentSynthesizer`

Arquivo puro `nonisolated` em
`Notinhas/Features/VideoEditor/Services/VideoEditorZoomSegmentSynthesizer.swift`:

- API: `static func segments(from presses: [RecordedMousePress], duration: TimeInterval) -> [ZoomSegment]`
- Filtrar só `.down`; aplicar constantes Screendrop da tabela acima.
- Cada segmento: `zoomType = .auto`, `zoomLevel = 1.5`, `isImplicit = true`,
  `zoomCenter` = posição do clique, `startTime`/`duration` derivados de
  start/end do cue.
- Clamp final com `ZoomSegment.clamped(to: videoDuration)`.
- Merge: mesma lógica one-pass do Screendrop.

Testes dedicados `VideoEditorZoomSegmentSynthesizerTests`:

- zero presses → `[]`
- clique único → janela [t−0.3, t+2.5] capada
- dois cliques dentro de joinTolerance → um segmento contínuo
- clique no último segundo → ignorado
- coords inválidas → ignoradas

**Verify:** compare casos canônicos com valores calculados manualmente a partir
do código Screendrop (não snapshot de código externo).

### Step 3: Estender `ZoomSegment` com `isImplicit`

- Campo `isImplicit: Bool = false`; `Codable` com default false para projetos
  futuros (não persistidos ainda neste plano).
- UI/timeline: badge ou estilo visual discreto para implícitos (opcional MVP:
  contagem na sidebar basta).
- Undo: regenerar/remove implícitos deve ser undoable como batch ou ações
  individuais — preferir uma ação `resynthesizeImplicitZooms` nomeada.

**Verify:** segmentos manuais nunca recebem `isImplicit` em `addZoom(at:)`.

### Step 4: Auto-popular ao abrir o editor

Em `VideoEditorState.loadMetadata()` / pós-load do asset:

1. Se `!isGIF`, metadata presente, preferência `autoGenerateZoomOnOpen` (default
   **true**), `zoomSegments.isEmpty` e `mousePresses` não vazio → chamar
   sintetizador e atribuir `zoomSegments`.
2. Não marcar `hasUnsavedChanges` na carga inicial (segmentos implícitos são
   ponto de partida, como Screendrop).
3. Gravações **sem** metadata ou **sem** presses: comportamento atual (timeline
   vazia).
4. Vídeos importados externos: nunca auto-gerar.

Expor:

- `recordedClickCount: Int`
- `implicitZoomSegmentCount: Int` (já existe `autoZoomSegmentCount` por
  `zoomType`; separar contagem **implícita** vs auto manual)
- `func resynthesizeImplicitZoomSegments()` — remove implícitos, regera a partir
  de metadata; undoable
- `func removeAllImplicitZoomSegments()` — opcional, via regenerar com zero clicks

**Verify:** state tests para load com/sem presses, preferência off, segmentos
manuais preservados na regeneração.

### Step 5: UI e preferências

**Preferências (Recording ou Video Editor):**

- Toggle: “Gerar zooms automaticamente ao abrir gravações” (default on).
- Help text: explica cliques na área gravada; editável depois.

**Video Editor sidebar (seção Zoom):**

- Linha: “Cliques gravados: N” (0 se sem metadata).
- Botão secundário: “Regenerar zooms automáticos” → `resynthesizeImplicitZoomSegments()`.
- Confirmar se N=0 (desabilitar botão + hint).
- Master toggle `zoomEnabled` **não** necessário neste MVP — segmentos
  individuais já têm `isEnabled`; opcional: toggle global se já existir padrão
  no código.

Localize PT/EN via `VideoEditor.xcstrings` / `Recording.xcstrings`.

**Verify:** inspeção visual light/dark; VoiceOver nos botões novos.

### Step 6: Documentar e validar

Atualizar docs:

- `RECORDING.md`: metadata v7, `mousePresses`, alinhamento temporal, dedup.
- `VIDEO_EDITOR.md`: auto-populate, regenerar, constantes Screendrop, diferença
  vs plano 110 (física/ cursor).

Gates: testes focados, `make test-video`, format, lint, agent-check, verify map.

Manual obrigatório:

1. Grave área com 3+ cliques espaçados; abra editor → segmentos aparecem na
   timeline com Follow Mouse ativo.
2. Regenerar após mover um segmento manual → manuais permanecem, implícitos
   substituídos.
3. Gravação antiga (v6) abre sem crash; sem auto-zoom até regravar.
4. Export com zooms auto → arquivo inclui zoom (compositor existente).
5. Preferência off → timeline vazia na abertura.
6. Screenshots ou gravação curta para handoff.

## Test plan

### XCTest obrigatório

- `RecordingMetadataStoreTests`: v7 encode/decode, v6 migration, canonicalize.
- `RecordingClickRecorderTests` ou extensão de mouse tracker: timing, pause,
  dedup, boundary.
- `VideoEditorZoomSegmentSynthesizerTests`: casos canônicos Screendrop.
- `VideoEditorZoomAndAutoFocusTests`: regressão Follow Mouse com segmentos
  sintetizados.
- `VideoEditorStateTests` (novo ou extensão): auto-populate, resynthesize,
  manual preservation.

### Manual obrigatório

Ver Step 6.

## Done criteria

- [ ] Cliques `down`/`up` persistidos em metadata v7 com timeline alinhado ao vídeo.
- [ ] Gravações v6 continuam abrindo; `mousePresses` vazio.
- [ ] Sintetizador reproduz constantes e merge do Screendrop @ `57a48dd`.
- [ ] Editor auto-popula segmentos implícitos na abertura (pref on, presses > 0).
- [ ] “Regenerar zooms automáticos” substitui só implícitos; undo funciona.
- [ ] Magnificação auto = **1,5×**; segmentos usam Follow Mouse (`.auto`).
- [ ] Export/preview existentes aplicam zoom sintetizado sem regressão screen-only.
- [ ] Preferência documentada; default on.
- [ ] Testes, build/test Video, format, lint, agent-check passam ou baseline explícito.
- [ ] Gate manual registrado com evidência visual.

## STOP conditions

- Timestamps de clique sistematicamente defasados vs playback (>100 ms) sem
  correção determinística.
- Auto-populate sobrescreve segmentos manuais do usuário.
- Metadata v7 quebra gravações existentes em produção.
- Sintetizador exige inferir cliques só a partir de `mouseSamples` (proibido —
  exige captura explícita).
- Escopo expande para cursor sintético ou molas — pare e mova para plano 110.

## External-state addendum

- **Authority:** `RecordingMetadata` é fonte de cliques; segmentos implícitos são
  derivados e regeneráveis.
- **Identity:** presses keyed by recording entry UUID; segmentos by UUID.
- **Scope:** gravações Notinhas com metadata; não vídeos externos.
- **Preflight:** validar duration > 0 antes de sintetizar.
- **Idempotency:** resynthesize é determinístico para mesma metadata + duration.
- **Failure:** gravação sem presses degrada para workflow manual atual, sem alerta
  blocking.
- **Concurrency:** captura de cliques on MainActor com monitors existentes;
  sintetizador pure/off MainActor.

## Maintenance notes

- Este plano fecha o gap **funcional** de zoom automático; a **sensação**
  visual 1:1 (molas, cursor reconstruído) é plano 110.
- Não alterar `showsCursor` neste plano — evita mudar gravações existentes.
- Se join/pre/post-roll precisarem tuning, centralize constantes num único enum
  espelhando Screendrop para diff futuro fácil.
