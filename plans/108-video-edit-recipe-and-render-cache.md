# Plan 108: Persistir receita de exportação e cachear renders do Video Editor

> **Instruções para o executor:** este é um plano P2 e começa por uma
> caracterização curta. A entrega não é um novo formato de projeto, autosave de
> drafts ou sincronização entre máquinas. O objetivo mínimo é tornar exports
> repetidos determinísticos e reaproveitáveis, guardando uma receita canônica
> junto do cache para que um hit nunca seja confundido com arquivo de origem.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat ac4dda65..HEAD -- Notinhas/Features/VideoEditor Notinhas/Services/Capture/RecordingMetadata.swift Notinhas/Services/Capture/TempCaptureManager.swift NotinhasTests/Features/VideoEditor NotinhasTests/Services/Capture`
>
> Use `.worktrees/video-edit-recipe-render-cache` e branch
> `video-edit-recipe-render-cache`. Merge/push não são autorizados por este
> plano. Se o plano 107 ainda não estiver integrado, o campo de câmera da
> receita deve ser opcional e o plano não deve antecipar a implementação dele.

## Status

- **Priority:** P2
- **Effort:** M/L
- **Risk:** MED
- **Depends on**: plano 104 recomendado; serialize com plano 107 se a receita incluir layout de camera
- **Category:** architecture / perf
- **Planned at**: commit `ac4dda65` after local integration of Plans 104–107, 2026-08-23
- **Finding ID:** `video-edit-recipe-render-cache`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem autorização explícita

## Execution profile

- **Recommended profile:** `implementer` depois da caracterização; `advisor`
  deve ser usado se a política de source/master não puder ser fechada
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** não com mudanças no exporter/window controller; pode ser
  paralelo a captura PiP somente se não tocar os mesmos models
- **Reviewer required:** sim; hashing/canonicalização, cache invalidation,
  sandbox, Replace Original e deleção de cache
- **Rationale:** o cache pode economizar um export caro, mas um hit errado pode
  publicar vídeo velho ou aplicar receita duas vezes. A política de identidade é
  mais importante que a pasta de arquivos.
- **Escalate when:** for necessário autosave de drafts, reabrir uma receita
  sobre um arquivo já renderizado, sincronizar entre máquinas ou manter
  masters separados; isso exige um projeto persistente e outro plano.

## Why this matters

O Video Editor mantém trim, zoom, speed, background, áudio e settings apenas em
memória até o export. O exporter escreve diretamente no output solicitado e
normaliza áudio; não há recipe canônica nem cache. Repetir um export para testar
qualidade, gerar uma cópia ou corrigir o destino reprocessa tudo.

A referência do [Screendrop](https://github.com/fayazara/Screendrop) reforça a
separação entre masters, metadata e deliverables. No Notinhas, a versão mínima
é um cache local privado, com recipe e fingerprint, sem copiar implementação
CC0, sem cloud e sem transformar cada vídeo em um documento de projeto.

## Current state

- `VideoEditorState` possui `trimStart`, `trimEnd`, `zoomSegments`,
  `speedSegments`, `isMuted`, `backgroundStyle`, padding/shadow/corner,
  `exportSettings`, metadata e `hasUnsavedChanges`; `undoStack` é apenas
  memória da janela.
- `ZoomSegment` e `SpeedSegment` já são `Codable`; `ExportSettings` é somente
  `Equatable`; `BackgroundStyle` usa a conversão concreta
  `CodableBackgroundStyle` em outras superfícies, mas o exporter não tem uma
  receita própria.
- `VideoEditorExporter.exportTrimmed()` escolhe export standard/composition e
  chama `normalizeExportAudioForCompatibilityIfNeeded` diretamente no output.
  `replaceOriginal()` exporta para temp, faz backup e move de forma atômica;
  `saveAsCopy()` exporta para o destino escolhido.
- `VideoEditorWindowController` publica thumbnail/clipboard/History depois do
  sucesso; qualquer cache deve acontecer antes de esses efeitos, mas não deve
  substituir a validação existente.
- `RecordingMetadataStore` já resolve URL por bookmark e possui limpeza de
  metadata/audio sources, mas `RecordingMetadata` é captura/track context, não
  uma receita de UI. Não aumente a versão dele apenas para colocar cache se um
  store separado for menor.
- Não existe pasta de render cache, chave canônica, fingerprint de source ou
  política de LRU/retention. Não use `hashValue`, nome do arquivo ou path puro.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Export tests | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorExportSettingsTests` | exit 0 |
| Speed/recipe values | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorSpeedTimeMapTests` | exit 0 |
| Zoom/export behavior | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor/VideoEditorZoomAndAutoFocusTests` | exit 0 |
| Metadata cleanup, se tocado | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Format/lint | `make format-check && make lint-changed` | exit 0 |
| Build | `make build-video` | exit 0 |
| Tests | `make test-video` | exit 0 |
| Agent gate | `make agent-check` | exit 0 ou baseline exato |
| Verify map | `./scripts/verify-local.sh --base ac4dda65 --full --plan-only --strict` | superfície coberta |

Para caracterização, exporte o mesmo vídeo/configuração duas vezes e registre
tempo/tamanho sem guardar o vídeo no repositório. Se não houver cenário real de
repetição, o plano pode parar sem criar cache; documente a decisão.

## Suggested toolkit

- `Codable` + `JSONEncoder.outputFormatting = [.sortedKeys]` para receita
  canônica; não depender de ordem incidental de propriedades.
- `CryptoKit.SHA256` nativo para hash da receita/fingerprint; não adicionar
  pacote.
- `FileManager` + `Data.write(options: .atomic)` e rename dentro de um root de
  App Support validado.
- `AVAsset.load(.duration)`/tracks para validar cache antes de reutilizar.
- `SandboxFileAccessManager` para source/output do usuário; cache interno não
  deve exigir permissão de escrita no diretório do vídeo.
- Um `VideoEditorRenderCacheStore` concreto, sem protocolo/factory, somente se
  a caracterização justificar o cache.

## Scope

**In scope:**

- `Notinhas/Features/VideoEditor/VideoEditorState.swift` para snapshot da
  receita, sem persistir playback/undo/UI chrome
- `Notinhas/Features/VideoEditor/Models/` para recipe value types concretos
- `Notinhas/Features/VideoEditor/Services/VideoEditorExporter.swift`
- novo `Notinhas/Features/VideoEditor/Services/VideoEditorRenderCacheStore.swift`
  ou store equivalente sob App Support
- `Notinhas/Features/VideoEditor/Managers/VideoEditorWindowController.swift`
  somente para publicação/erro/progress de cache hit
- `Notinhas/Services/Capture/RecordingMetadata.swift` somente se a associação
  do source exigir extensão mínima; preferir não alterar schema de captura
- testes do Video Editor/cache e docs de export

**Out of scope:**

- autosave de edição não exportada, restore automático de draft ou projeto
  “.notinhas”
- aplicar uma recipe antiga automaticamente sobre um vídeo que já foi renderizado
- sincronização/cloud, compartilhamento, upload ou cache entre usuários
- cache de GIF, thumbnails ou frames de timeline (eles já têm owners)
- cache de source, masters ou qualquer arquivo escolhido pelo usuário
- alterar algoritmo de zoom/audio/codec para aumentar hit rate

## Git workflow

1. Crie `.worktrees/video-edit-recipe-render-cache` a partir do SHA verificado.
2. Faça Step 1 primeiro. Se o stop condition de YAGNI for atingido, entregue
   somente a caracterização/documentação, sem store.
3. Separe commits de recipe, store e integração do exporter.
4. Não misture correções de compositor PiP ou refactors gerais de state.
5. Deixe branch/worktree para revisão; merge/push não estão autorizados.

## Steps

### Step 1: Medir a necessidade e fechar a autoridade

Registre uma execução de export repetida com:

- mesmo source e mesmo state;
- source com trim/zoom/speed/background/audio custom;
- Save As para dois destinos;
- Replace Original em fixture descartável, nunca em mídia pessoal sem backup.

Compare tempo, tamanho e se o output é determinístico o suficiente para ser
reutilizado. Em seguida feche a política:

- source asset é somente leitura durante export;
- recipe descreve o input e o exporter version, não a janela/undo;
- cache output é um deliverable interno, não um novo source;
- arquivo fonte não recebe sidecar obrigatório nem é modificado para criar
  cache;
- abrir um vídeo já exportado continua abrindo o vídeo pronto, sem aplicar uma
  recipe novamente.

Se o problema não aparecer em um cenário real, pare aqui e registre “cache
adiado por falta de custo repetido”; não crie infraestrutura por analogia.

**Verify:** handoff contém medida/decisão e nenhum arquivo de produto foi
alterado além de documentação, se o plano parar.

### Step 2: Modelar uma recipe canônica e Sendable

Crie um value type concreto, por exemplo `VideoEditorExportRecipe`, com
`Codable`, `Equatable` e `Sendable` quando o Swift 6.2 permitir. Inclua somente
o que muda bytes do export:

- schema version e `exporterImplementationVersion`;
- trim start/end em representação CMTime estável (value + timescale ou
  unidade quantizada definida/testada, nunca `String(describing:)`);
- zoom/speed segments em ordem determinística;
- mute/audio mode/volumes e todos os export dimension/quality fields;
- background codificado de forma completa, incluindo URL/fingerprint de
  wallpaper quando o efeito depender de arquivo externo;
- camera overlay layout somente quando o plano 107 estiver integrado;
- source fingerprint separado da recipe.

Exclua currentTime, isPlaying, scrubbing, selected IDs, sidebar visibility,
undo/redo, progress, estimated size e caminhos de cache.

Faça `canonicalData` com JSON sorted keys e `cacheKey` com SHA-256. Dois states
semanticamente iguais devem produzir a mesma chave; mudar qualquer input de
render deve produzir chave diferente. Incrementar `exporterImplementationVersion`
deve invalidar renders quando o compositor mudar.

**Verify:** testes de igualdade/chave, ordem de arrays, CMTime, settings,
background externo e inclusão condicional da camera.

### Step 3: Criar cache store bounded e seguro

Se Step 1 justificou o cache, implemente um store concreto em App Support,
por exemplo:

`Application Support/Notinhas/VideoRenderCache/<key>/manifest.json`
`Application Support/Notinhas/VideoRenderCache/<key>/render.<ext>`

O manifest deve guardar schema, key, source fingerprint, recipe canonicalizada,
output extension/type, duration, video/audio track counts, byte size, createdAt
e lastUsedAt. Regras:

- criar diretório somente sob o root calculado pelo app;
- escrever manifest/output temporários e promover atomicamente;
- validar cache hit por manifest + fingerprint + existência + AVAsset legível;
- se qualquer dado estiver corrompido/stale, tratar como miss e remover apenas
  a entrada do cache;
- atualizar `lastUsedAt` de forma atômica e tolerar crash entre render e
  manifest;
- limitar retenção por constantes conservadoras (por exemplo 1 GiB e 30 dias)
  ou, se a medição não justificar número, começar somente com limpeza por idade
  registrada. Não transforme limites em preferências sem demanda;
- cleanup nunca atravessa o cache root nem toca source/output do usuário.

Não use filename do vídeo, `URL.path` ou `hashValue` como identidade. Use
fingerprint com size, modification date, resource identifier/bookmark quando
disponível; se o fingerprint não puder ser confiável, desabilite cache hit para
aquele source.

**Verify:** store tests para miss/hit, source alterado, recipe alterada,
manifest corrompido, output ausente, crash parcial, LRU/idade e path guard.

### Step 4: Integrar cache ao exporter sem mudar o contrato de output

Antes do export, `VideoEditorExporter` deve capturar um snapshot imutável de
state/recipe/source fingerprint. Não leia propriedades mutáveis depois de um
`await` para formar uma chave diferente da que foi validada.

Fluxo de miss:

1. derive key;
2. exporte usando o pipeline existente para o output temporário/destino;
3. normalize áudio como hoje;
4. valide duração/tracks/tamanho;
5. copie o output validado para o cache com manifest atômico;
6. devolva o output original à camada de Save/Quick Access.

Fluxo de hit:

1. valide manifest/fingerprint/asset;
2. copie o render do cache para o output solicitado usando o access scope atual;
3. atualize `lastUsedAt` sem bloquear o export;
4. publique progress 1.0/status “reutilizado” somente depois de a cópia
   terminar.

Não pule `markAsSaved`, `refreshItemThumbnail`, `CaptureHistoryStore` ou
`PostCaptureActionHandler`: cache é otimização interna. Preserve a semântica
de `replaceOriginal` (temp output, backup, restore em erro) e `saveAsCopy`
(destino escolhido). Nunca copie cache diretamente sobre o original sem o
   backup/atomic replace existente.

Se o output tiver formato, audio normalization ou camera composition que o
cache não consegue representar com exatidão, faça miss; não faça aproximação.

**Verify:** export miss/hit para Save As, Replace Original, temp capture,
custom audio, zoom/background/speed e camera quando disponível; falha de cópia
não perde source nem deixa UI em exporting.

### Step 5: Associar a recipe sem re-aplicá-la indevidamente

Persistir recipe no manifest do cache é suficiente para este plano. Não faça
`VideoEditorState.init` aplicar automaticamente uma recipe encontrada para uma
URL, porque o output de Save As/Replace já contém os efeitos baked e seria
renderizado duas vezes.

Se a implementação mostrar que o usuário precisa reabrir edições não baked,
pare e escreva um ADR/plano separado que defina:

- identidade master vs derivative;
- como Replace Original muda fingerprint/authority;
- como drafts são confirmados/restaurados;
- como metadata/History apontam para o master;
- como uma recipe antiga é invalidada.

Para o plano atual, o manifest pode ser usado para diagnóstico/cache hit e não
deve alterar a UI de reopen. `markAsSaved()` continua apenas atualizando a
linha de base em memória; o cache é committed após output validado.

**Verify:** reabrir um output baked não aplica a recipe novamente; abrir source
sem cache continua com defaults atuais; cache hit produz bytes/track semantics
equivalentes ao miss.

### Step 6: Limpeza, documentação e gates

Documente em `docs/VIDEO_EDITOR.md`:

- recipe é manifest interno de export;
- cache fica em App Support e é descartável;
- source/output do usuário não são cacheados nem apagados pelo cleanup;
- cache miss é comportamento normal;
- restore de draft/master não está incluído.

Adicione logs sem path completo, tokens, recipe JSON ou conteúdo de vídeo; use
key prefix, hit/miss, duration e byte count. Rode testes, format, lint,
agent-check e verify map. Se a mudança tocar UI de status, faça manual gate
visual; se tocar apenas exporter/store, a manual validação pode ser por output
e Finder.

**Verify:** cache directory pode ser apagado pelo usuário sem quebrar o app;
próximo export apenas faz miss.

## Test plan

### XCTest obrigatório

- `VideoEditorExportRecipeTests`: canonical JSON/key, defaults, CMTime,
  settings, background, camera optional e exporter version.
- `VideoEditorRenderCacheStoreTests`: root guard, atomic manifest, hit/miss,
  invalid source, invalid recipe, corrupt/partial entry, retention e cleanup.
- exporter tests: miss/hit equivalence, no-cache fallback, audio normalization,
  composition camera, Save As/Replace output validation.
- state tests: snapshot não inclui playback/undo/UI, recipe não altera
  `hasUnsavedChanges` indevidamente.

Fixtures devem ser sintéticas/temporárias e removidas no teardown; não use
arquivos de `~/Documents` do usuário.

### Manual obrigatório depois da integração

1. Exporte uma gravação com trim/zoom/background/audio; registre tempo e output.
2. Repita sem mudar state e confirme log de hit, mesmo tamanho/duração e
   clipboard/thumbnail normais.
3. Modifique uma opção e confirme miss; altere o source e confirme miss.
4. Feche o app/apague somente a pasta de cache via procedimento manual de
   teste e confirme que o source/History continuam intactos.
5. Reabra o output e confirme que nenhum efeito é aplicado uma segunda vez.
6. Teste Replace Original em fixture descartável e force erro de cópia para
   confirmar restore do backup existente.

## Done criteria

- [ ] Step 1 tem evidência de custo repetido ou decisão explícita de adiar por
      YAGNI.
- [ ] Recipe cobre todos os inputs que alteram render e exclui estado efêmero.
- [ ] Key canônica é determinística e versionada; não usa `hashValue`/path puro.
- [ ] Cache fica em App Support, é bounded/limpável e nunca toca mídia do
      usuário durante cleanup.
- [ ] Hit valida source/recipe/output antes de copiar.
- [ ] Miss usa exatamente pipeline/normalização existentes e commit só depois
      de output válido.
- [ ] Save As/Replace/temp/History/Quick Access mantêm seus contratos.
- [ ] Reabrir output baked não aplica recipe duas vezes.
- [ ] Camera layout entra na key somente quando o plano 107 existir.
- [ ] Testes, build/test Video, format, lint, agent-check e verify local passam
      ou registram baseline exato.

## STOP conditions

- Não há evidência de export repetido caro e a única justificativa é “Screendrop
  tem cache”; pare sem store.
- Recipe não consegue representar background externo, audio mix, speed,
  camera ou versão do compositor; faça miss em vez de hit inseguro.
- Fingerprint pode aceitar source modificado como o mesmo asset.
- Cache hit altera clipboard/History/thumbnail ou pula a validação de output.
- Replace Original pode perder backup, ou cleanup alcança fora do cache root.
- A única forma de “persistir recipe” é aplicar automaticamente sobre output já
  baked; abra plano de master/draft separado.
- Um gate determinístico falha duas vezes após correção razoável.

## External-state addendum

- **Authority:** source fingerprint + recipe + exporter version determinam a
  validade; cache manifest descreve apenas deliverable descartável; source e
  output escolhido pelo usuário vencem qualquer cache.
- **Identity:** SHA-256 da recipe canônica combinado com fingerprint do source,
  output type/extension e versão do exporter.
- **Scope:** somente `Application Support/Notinhas/VideoRenderCache/` e um
  output temporário/explicitamente escolhido pela operação corrente.
- **Preflight:** verificar root, fingerprint, recipe snapshot, sandbox access,
  cache manifest e AVAsset antes de hit/copy/cleanup.
- **Idempotency:** key única evita duplicação; commit repetido atualiza a
  entrada depois de validar; hit não cria History record adicional.
- **Failure:** miss/manifest corrupto/output inválido faz fallback para export;
  falha de cache nunca impede export se o pipeline principal funciona.
- **Concurrency:** uma key pode ter um writer de commit; outro pedido espera,
  reutiliza ou abandona temp sem publicar manifest parcial. Export cancellation
  não publica cache incompleto.
- **Destructive actions:** cleanup só remove entradas dentro do cache root,
  com idade/limite comprovado; nunca remove source, backup de Replace ou
  metadata de usuário.

### High-risk traceability

| Invariante | Implementação | Evidência |
| --- | --- | --- |
| hit representa o mesmo render | recipe/fingerprint/version canônicos | key/fixture tests + miss/hit comparison |
| source não é alterado pelo cache | root separado + sandbox copy | path guard + manual deletion |
| falha de cache não perde export | fallback miss → exporter atual | exporter failure tests |
| output baked não recebe recipe duas vezes | no auto-restore; recipe só manifest | reopen manual + state tests |
| Replace continua recuperável | cache alimenta temp, backup permanece | replacement failure test/manual |

## Maintenance notes

- Este plano escolhe o menor significado útil de “persistir receita”: manifest
  durável para cache/diagnóstico, não um novo formato de projeto.
- Reabrir drafts/master é uma decisão de produto separada e deve incluir ADR;
  não inferir autoridade a partir de filename ou cache key.
- Incrementar `exporterImplementationVersion` é obrigatório quando mudar
  compositor, audio normalization, camera layout ou qualquer regra que altere
  pixels/bytes.
- Se o cache não produzir hits em uso real após uma versão, considerar removê-lo
  antes de adicionar limpeza, preferências ou telemetria.
