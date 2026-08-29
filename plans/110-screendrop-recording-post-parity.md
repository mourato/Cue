# Plan 110: Paridade completa de gravação/pós-processamento com Screendrop

> **Instruções para o executor:** execute **depois** do plano 109. Este plano
> fecha a lacuna visual e estrutural restante entre o Notinhas Video Editor e o
> Studio do Screendrop (@ `57a48dd`): física de viewport, modos de âncora,
> cursor/cliques/teclas reconstruídos no pós, timeline multi-clip, reframe,
> presets de estilo e cache de render. Reimplementação independente; referência
> em `~/Documents/Projects/References/Screendrop/`.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat <109-merge-commit>..HEAD -- Notinhas/Services/Capture Notinhas/Features/Recording Notinhas/Features/VideoEditor NotinhasTests docs/RECORDING.md docs/VIDEO_EDITOR.md scripts/verification-map.tsv`
>
> Substitua `<109-merge-commit>` pelo SHA integrado do plano 109 antes de
> implementar.
>
> Use `.worktrees/screendrop-recording-post-parity` e branch
> `screendrop-recording-post-parity`. Merge/push não são autorizados por este plano.

## Status

- **Priority:** P2
- **Effort:** L (multi-fase; pode ser fatiado em sub-entregas com review entre
  fases)
- **Risk:** HIGH
- **Depends on:** plano 109 (metadata de cliques + sintetizador + auto-populate)
- **Category:** feature / architecture / performance
- **Planned at**: commit `ee55c91a`, 2026-08-29
- **Finding ID:** `screendrop-recording-post-parity`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem
  autorização explícita

## Execution profile

- **Recommended profile:** `implementer` (faseado)
- **Risk/lane:** `High/Full`
- **Parallelizable:** não; serializar com qualquer plano que toque
  `ScreenRecordingManager`, `RecordingMetadata`, `VideoEditorState`,
  `VideoEditorZoomCompositor`, `VideoEditorExporter`
- **Reviewer required:** sim; compositor frame-a-frame, sync multi-player,
  coordenadas top-left/bottom-left, regressão export screen-only
- **Rationale:** paridade 1:1 exige trocar ease cúbico por timeline de viewport
  pré-computada, adicionar camadas sintéticas e expandir o modelo de timeline —
  alto risco de regressão no fast path.
- **Escalate when:** ocultar cursor na captura quebrar gravações legadas; custo
  de export frame-a-frame inviabilizar vídeos >5 min sem cache; ou multi-clip
  exigir reescrever `VideoEditorSpeedTimeMap` sem plano de migração.

## Why this matters

O plano 109 entrega zoom automático **funcional** (cliques → segmentos). O
Screendrop vai além: master sem cursor, ponteiro/cliques/teclas reconstruídos,
viewport com molas @ 120 Hz, âncoras smart/pinned, timeline de clips com
speed, reframe para aspect ratios e flatten cacheado. Screen Studio (referência
paga) compartilha esse padrão de “gravação crua + composição polida”.

Sem este plano, exportações Notinhas continuam com cursor baked, transições de
zoom menos naturais e timeline single-trim — perceptivelmente abaixo das
referências de mercado para demos de produto.

## Current state (pós-109 assumido)

- Cliques em metadata v7; `VideoEditorZoomSegmentSynthesizer` gera implícitos.
- Follow Mouse: `VideoEditorAutoFocusEngine` com dead-zone + smoothing exponencial
  @ ≤60 Hz dentro do segmento.
- Zoom transition: ease-in-out cúbico (`VideoEditorZoomCalculator`).
- Cursor: SCK `showsCursor` default on; click highlight opcional baked.
- Timeline: trim global; speed segments separados; sem split/delete.
- Export: `ZoomCompositor` CI/Metal; sem motion blur; sem cache (Plan 108 YAGNI).
- Projeto: edições voláteis; sem `edit.json`.
- Câmera PiP: planos 106–107 entregues.

## Screendrop parity target (completo)

Referência: `RecordingViewportTimeline.swift`, `RecordingPointerTimeline.swift`,
`RecordingOverlayEffects.swift`, `RecordingClipTimeline.swift`,
`RecordingExportReframe.swift`, `RecordingStudioExporter.swift`,
`RecordingSessionRenderer.swift`, `RecordingStudioStylePresetStore.swift`.

| Área | Screendrop | Notinhas após 109 | Este plano |
| --- | --- | --- | --- |
| Master sem cursor | ✅ | ❌ | ✅ opt-in + fallback |
| Presses + travel + artwork | ✅ | presses only | 🟡 artwork opcional P2 |
| Auto-zoom sintetizado | ✅ | ✅ (109) | manter |
| Viewport @ 120 Hz + springs | ✅ | ❌ cubic | ✅ |
| Anchor pointer/smart/pinned | ✅ | ❌ | ✅ |
| Cursor reconstruído | ✅ | ❌ | ✅ |
| Click pulses pós | ✅ | ❌ | ✅ |
| Keystroke captions pós | ✅ | ❌ | ✅ |
| Multi-clip split/delete/speed | ✅ | ❌ | ✅ |
| Style presets gravação | ✅ | ❌ | ✅ |
| Reframe Fill/Fit | ✅ | 🟡 dims only | ✅ |
| Render cache + stamp | ✅ | ❌ | ✅ medido |
| Transcrição/teleprompter/cloud | ✅ | ❌ | **fora de escopo** |

## Phased delivery

Execute na ordem; cada fase tem gate próprio antes da seguinte.

### Fase A — Viewport timeline e modos de âncora

**Objetivo:** substituir/complementar `VideoEditorZoomCalculator` easing por
`ViewportTimeline` pré-computada espelhando Screendrop.

Entregas:

- `VideoEditorViewportTimeline.swift`: integração @ **120 Hz**,
  `SpringConstant(tension: 200, friction: 40, inertia: 2.25)`.
- Comfort widening (`travelComfortWidths = 1.4`), settle guard 150 ms,
  interior margin 0.9.
- `ZoomAnchorMode`: `.pointer`, `.smart`, `.pinned` mapeados para UI existente.
- Smart anchor: clustering por bbox dentro do cue; drop movement-only groups;
  activation = click − 0.3 s.
- `ZoomSegment` ganha `anchorMode`, `boundsBias` (default 0.25), `skipsEasing`.
- Preview + export usam **mesma** timeline imutável (interpolada).

Arquivos: `VideoEditorZoomCalculator.swift`, `VideoEditorAutoFocusEngine.swift`,
`VideoEditorZoomCompositor.swift`, `VideoEditorZoomPreviewOverlay.swift`,
`VideoEditorRightSidebar.swift`, modelos de zoom.

**Verify:** testes numéricos contra fixtures derivados do Screendrop; export
sintético curto byte-stable entre preview e export.

### Fase B — Cursor/cliques/teclas sintéticos no pós

**Objetivo:** master limpo + overlays reconstruídos no compositor (como
`pointerSynthesized` no Screendrop).

Entregas:

- Preferência de captura: ocultar cursor SCK para **novas** gravações quando
  “Smart pointer” ativo (default off até validação; migrar para on quando estável).
- Metadata v8 opcional: `pointerSynthesized: Bool`, artwork snapshots @ 30 Hz
  (simplificado: system arrow fallback se artwork pesado demais).
- `VideoEditorPointerTimeline.swift` @ 120 Hz com springs (glide/intercept/track/
  settle — constantes Screendrop).
- `VideoEditorOverlayEffects.swift`: click pulse 400 ms; keystroke captions com
  placement 6 posições, animação pop-in/hold/pop-out.
- Metadata v8: `keystrokes[]` (shortcuts only, mesma política do
  `KeystrokeMonitorService`).
- Toggles editor: `showsSyntheticCursor`, `showsClickEffects`, `showsKeystrokes`.
- Compositor: desenhar pointer + efeitos **depois** do zoom/background, antes
  da camera PiP.

**Verify:** gravação com smart pointer off = comportamento legado; on = export
sem cursor baked mas com pointer reconstruído; toggles WYSIWYG.

### Fase C — Timeline multi-clip

**Objetivo:** `RecordingClipTimeline` equivalente — split, delete, speed por clip.

Entregas:

- `VideoEditorClipTimeline.swift` + `VideoEditorClipSegment`: non-destructive
  map sobre asset source.
- Operações: split @ playhead (min 0.12 s cada lado), delete clip (≥2 clips),
  speed 1–8× por clip, reset para clip único.
- Integrar com `VideoEditorSpeedTimeMap` ou substituir por mapa clip-first —
  **uma** autoridade de tempo para playhead, zoom, pointer, export.
- UI: lane de clips ou extensão da timeline existente; undo nomeado.
- Zoom/pointer lookup via `clipTimeline.sourceTime(at: editorTime)`.

**Verify:** speed + zoom + trim combinados; regressão single-clip; GIF ainda
sem clip lane.

### Fase D — Estilo, reframe, cache

**Objetivo:** polish de export igual ao Studio.

Entregas:

- `VideoEditorStylePresetStore`: presets nomeados (background, padding, radius,
  shadow, cursor scale default 1.7×); aplicar preset ativo em novas gravações.
- `VideoEditorExportReframe.swift`: presets Original/16:9/9:16/1:1/4:5; modos
  Fill/Fit; `ReframeTrack` @ 120 Hz (dead zone 28%, τ=0.45 s).
- Export @ **60 fps** compositor frame-a-frame quando pointer/zoom/reframe
  sintéticos ativos; motion blur opcional (até 24 amostras) — feature flag se
  custo alto.
- **Render cache** (reavaliar Plan 108): manifest `render-recipe.json` ao lado
  do vídeo ou em App Support; skip re-render quando recipe unchanged; invalidar
  em qualquer edição.

**Verify:** caracterização de tempo de export 2×/5×/10× duração; cache hit/miss;
reframe Fill segue pointer.

### Fase E — Persistência de edição (opcional dentro deste plano)

**Objetivo:** não perder trabalho ao fechar editor.

- Sidecar `.<video-id>.edit.json` ou entrada em RecordingMetadata store com
  trim, clips, zooms (não implícitos filtrados se usuário editou), style, toggles.
- Autosave debounced 250 ms; draft vs saved.
- Reabrir Quick Access/History restaura edição **somente** no master multitrack;
  output baked nunca reaplica recipe (regra Plan 108).

**Escalate:** se autoridade master vs derivative não estiver clara, entregue
Fases A–D primeiro e fatie E.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Metadata | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Zoom/viewport | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorZoomAndAutoFocusTests` | exit 0 |
| Viewport (novo) | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorViewportTimelineTests` | exit 0 |
| Pointer (novo) | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorPointerTimelineTests` | exit 0 |
| Clips (novo) | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorClipTimelineTests` | exit 0 |
| Speed map | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorSpeedTimeMapTests` | exit 0 |
| Export | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorExportSettingsTests` | exit 0 |
| Build/test | `make build-video && make test-video` | exit 0 |
| Agent gate | `make agent-check` | exit 0 |

## Scope

**In scope:** arquivos listados nas fases A–E; docs; verification map; prefs.

**Out of scope (permanente):**

- Transcrição, teleprompter, cloud upload, App Intents de Studio
- Múltiplas câmeras, face tracking, background removal
- Formato de sessão pasta `*.screendroprec` — manter arquivo único + metadata
  Notinhas salvo migração explícita futura
- ScreenStudio-specific UX (timeline pro, presets pagos)
- Writer fragmentado — só reavaliar se Plan 104 metrics mostrarem necessidade;
  não bloquear paridade de composição

## Git workflow

1. Branch `.worktrees/screendrop-recording-post-parity` após 109 integrado.
2. Uma merge lógica por fase (A→E) ou PRs sequenciais; nunca fases paralelas no
   mesmo compositor.
3. Characterize performance antes de cache (Fase D).
4. Review obrigatório entre fases.

## Done criteria (completo)

- [ ] Viewport usa timeline @ 120 Hz com springs; preview = export em fixtures.
- [ ] Três modos de âncora funcionais; smart anchor ignora trânsito entre clusters.
- [ ] Novas gravações podem omitir cursor baked; pointer reconstruído no export.
- [ ] Click pulses e keystroke captions editáveis/toggleáveis no pós.
- [ ] Split/delete/speed por clip integrados ao mapa de tempo único.
- [ ] Presets de estilo aplicáveis; reframe Fill/Fit para aspect presets.
- [ ] Cache de render medido e ativo quando benefício > custo (ou documento YAGNI
      com números se ainda não valer).
- [ ] (Fase E) Sidecar de edição restaura sessão no master; baked output seguro.
- [ ] Gravações legadas e screen-only fast path preservados.
- [ ] Testes + gates passam; evidência manual comparando clip Notinhas vs Screendrop
      (mesma ação: 3 cliques + pan).

## STOP conditions

- Export frame-a-frame >3× tempo real em clip 1080p60 de 2 min sem cache e sem
  mitigação — pare na Fase D e entregue cache antes de B/C ou reduza escopo.
- Smart pointer quebra gravações sem metadata (fallback obrigatório).
- Multi-clip quebra zoom/pointer/speed existentes do plano 109.
- Qualquer fase exige transcrição/cloud — rejeitar e manter fora de escopo.
- Duas fases alteram `VideoEditorZoomCompositor.processRequest` simultaneamente.

## External-state addendum

- **Authority:** master multitrack + metadata sidecars; flatten/export é derivative.
- **Recipe stamp:** hash de trim + clips + zooms + style + toggles + reframe;
  reopen flatten nunca duplica efeitos.
- **Legacy:** `showsCursor=true` gravações permanecem válidas; toggles default
  off para sintético em arquivos antigos.
- **Concurrency:** compositor off MainActor; players MainActor; cancel export on
  window close.

## Comparison traceability (Screendrop → Notinhas)

| Screendrop | Notinhas (alvo) |
| --- | --- |
| `ZoomCueSynthesizer` | `VideoEditorZoomSegmentSynthesizer` (109) |
| `ViewportTimeline.build` | `VideoEditorViewportTimeline.build` |
| `PointerTimeline.build` | `VideoEditorPointerTimeline.build` |
| `PointerPressEffectStyle` | `VideoEditorOverlayEffects` |
| `RecordingClipTimeline` | `VideoEditorClipTimeline` |
| `ReframeTrack` | `VideoEditorExportReframe` |
| `RecordingStudioExporter` | estender `VideoEditorExporter` + compositor |
| `render.json` | `render-recipe.json` (Fase D) |
| `edit.json` | sidecar edit (Fase E) |

## Maintenance notes

- Paridade **visual** com Screen Studio não é critério — Screendrop @ `57a48dd`
  é a referência verificável.
- Fase B é a mais invasiva na captura; ship atrás de flag até QA manual amplo.
- Se Fase E atrasar, 109+110A–D ainda entregam valor; E é conforto, não bloqueio
  de zoom automático.
- Atualizar `.agents/overlays/benchmarking.md` consulta Screendrop para
  `57a48dd` após integração.
