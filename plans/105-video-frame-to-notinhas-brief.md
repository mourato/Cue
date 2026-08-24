# Plan 105: Levar o frame do playhead para o fluxo de brief do Notinhas

> **Instruções para o executor:** leia o plano inteiro antes de editar. Este é
> um vertical slice deliberadamente pequeno: um frame estático extraído do
> vídeo atual deve entrar no fluxo existente de screenshot → Quick Access →
> Annotate → clipboard. Não crie um editor de vídeo dentro do Annotate e não
> reencode o vídeo para obter um frame.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat 5974d106..HEAD -- Notinhas/Features/VideoEditor Notinhas/Features/Annotate Notinhas/Features/QuickAccess Notinhas/Services/Capture/PostCaptureActionHandler.swift NotinhasTests/Features/VideoEditor NotinhasTests/Services/Capture/PostCaptureActionHandlerTests.swift`
>
> A implementação deve usar worktree `.worktrees/video-frame-to-brief` e branch
> `video-frame-to-brief`. Merge/push não são autorizados por este plano.

## Status

- **Priority:** P1
- **Effort:** M
- **Risk:** MED
- **Depends on**: nenhum; pode ser executado antes dos planos de câmera, mas deve ser serializado com qualquer mudança simultânea em `VideoEditorState`/toolbar
- **Category:** direction / feature
- **Planned at**: commit `5974d106`, 2026-08-23 (after Plan 104 local integration)
- **Finding ID:** `video-frame-to-brief`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem autorização explícita

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `Medium/Full`
- **Parallelizable:** sim em relação ao plano 104; não em relação a outro
  trabalho que edite a toolbar, `VideoEditorState` ou `PostCaptureActionHandler`
- **Reviewer required:** sim; conferir MainActor, retenção do arquivo, abertura
  do Annotate e semântica de localização
- **Rationale:** o recurso reutiliza vários owners maduros e pode ser entregue
  sem novo modelo de anotação, novo formato de vídeo ou nova dependência.
- **Escalate when:** a equipe decidir que o frame precisa incluir zoom,
  background, padding ou speed já renderizados; isso muda o problema para um
  export/compositor e não deve ser escondido neste plano.

## Why this matters

O vídeo é bom para explicar uma interação, mas o handoff do Notinhas continua
mais claro quando o desenvolvedor recebe uma imagem com pins e notas. O
playhead já aponta para o momento relevante e o Annotate já sabe produzir a
saída clipboard-ready; falta apenas uma ponte explícita.

Essa ponte também é coerente com a referência de engenharia do
[Screendrop](https://github.com/fayazara/Screendrop): usar playback como origem
de um deliverable específico, sem transformar o produto em um Loom genérico.
Nenhum código ou asset da referência deve ser copiado.

## Current state

- `VideoEditorState` é `@MainActor` e expõe `playbackState.currentTime`; o
  comentário em `currentPreviewRate` registra que o playhead permanece na
  coordenada absoluta do asset mesmo quando há `SpeedSegment`.
- `VideoEditorState.generateFrameThumbnails()` já usa
  `AVAssetImageGenerator`, `appliesPreferredTrackTransform` e tolerâncias
  adaptativas para a tira da timeline (`VideoEditorState.swift:765–798`).
  `QuickAccessThumbnailGenerator` e `HistoryThumbnailGenerator` também são
  exemplos de geração de frame. Reutilize o comportamento nativo; não adicione
  FFmpeg ou outra biblioteca.
- `VideoEditorToolbarView` tem um `fileActionsGroup` pequeno e o
  `VideoEditorMainView` injeta a toolbar no topo. É o ponto mais barato para uma
  ação explícita que não roube espaço da timeline.
- `PostCaptureActionHandler.handleScreenshotCapture(url:)` já concentra ações
  de screenshot, Quick Access, History, clipboard, presets e Annotate. O
  método `QuickAccessManager.addScreenshot(url:)` e
  `AnnotateManager.openAnnotation(for:)` já resolvem thumbnail e item-scoped
  session.
- A preferência `openAnnotate` para recording é deliberadamente desligada; o
  botão explícito “Anotar frame” deve abrir Annotate como consequência da ação
  do usuário, sem alterar a matriz global de post-capture.
- Não há hoje uma ação que extraia um frame do vídeo e o trate como screenshot.
- O editor atual renderiza zoom/background na reprodução/export, mas o
  `AVAssetImageGenerator` extrai o frame bruto do asset. O MVP deste plano
  assume explicitamente o frame bruto, com orientação da track aplicada. Um
  frame “como exportado” é outro problema.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Teste do estado/editor | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/VideoEditor` | exit 0 |
| Testes de post-capture | `./scripts/run-tests.sh -only-testing:NotinhasTests/Services/Capture/PostCaptureActionHandlerTests` | exit 0 |
| Teste de metadata/thumbnail, se tocado | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Formato | `make format-check` | exit 0 |
| Lint Swift alterado | `make lint-changed` | exit 0 |
| Build do módulo | `make build-video` | exit 0 |
| Testes do módulo | `make test-video` | exit 0 |
| Gate do agente | `make agent-check` | exit 0 ou baseline explícito |
| Verify map | `./scripts/verify-local.sh --base 6106c84 --full --plan-only --strict` | superfície coberta |

Se o runner não aceitar o filtro de diretório, use os identificadores de classe
que o script imprimir e registre o comando efetivamente executado.

## Suggested toolkit

- `AVAssetImageGenerator.image(at:)`/`copyCGImage(at:actualTime:)` com
  `appliesPreferredTrackTransform = true`.
- ImageIO (`CGImageDestination`) para escrever PNG atomicamente; não use
  `NSImage` como formato intermediário em uma task não isolada ao MainActor.
- `CaptureOutputNaming` e `TempCaptureManager` para URL temporária; reutilize
  `PostCaptureActionHandler` para as ações pós-captura.
- Uma função concreta `VideoFrameExtractor` só se a lógica não puder ser
  extraída/reutilizada do código de thumbnails. Não crie protocolo para um
  único extractor.

## Scope

**In scope:**

- `Notinhas/Features/VideoEditor/VideoEditorState.swift`
- `Notinhas/Features/VideoEditor/Components/VideoEditorToolbarView.swift` ou
  `VideoEditorMainView.swift`, conforme o menor seam
- `Notinhas/Features/VideoEditor/Managers/VideoEditorWindowController.swift`
  somente se o callback de abertura precisar ficar no controller
- um serviço/modelo concreto pequeno em
  `Notinhas/Features/VideoEditor/Services/`, se necessário
- `Notinhas/Services/Capture/PostCaptureActionHandler.swift`
- localização Recording/VideoEditor/Capture e labels de acessibilidade
- testes correspondentes em `NotinhasTests/Features/VideoEditor/` e
  `NotinhasTests/Services/Capture/`
- `docs/VIDEO_EDITOR.md` ou `docs/POST_CAPTURE.md` para documentar o fluxo

**Out of scope:**

- rasterizar zoom, background, padding, cursor effects ou speed segments no
  frame; o MVP é o frame bruto orientado da track
- anotação de vídeo, pins temporais, notas sincronizadas ou exportação de vídeo
- novo formato/sidecar de metadata para source/time
- mudar defaults de clipboard, Quick Access, History ou `openAnnotate`
- cloud/upload, OCR automático ou captura de câmera
- suporte a GIF; o botão deve ficar oculto/desabilitado em `state.isGIF`

## Git workflow

1. Crie `.worktrees/video-frame-to-brief` a partir do SHA verificado.
2. Faça primeiro a extração/rota com testes; só depois ajuste copy e layout.
3. Não altere o esquema padrão nem arquivos fora da lista sem atualizar o
   escopo e parar para revisão.
4. Deixe branch/worktree para outro agente revisar; não faça merge/push.

## Steps

### Step 1: Fixar a política do frame e o contrato de rota

Documente no código e nos testes:

- tempo solicitado = snapshot de `playbackState.currentTime` no clique;
- tempo é limitado ao intervalo válido do asset, sem usar `trimStart` como
  zero do asset;
- o frame é bruto, com `preferredTransform`, e não inclui efeitos de editor;
- o arquivo é PNG e entra como screenshot, portanto pins/notas/export seguem
  o Annotate existente;
- falha de extração deixa o vídeo aberto e não cria item parcial.

Crie uma função pura para clamp/nome, se útil, e teste fim do asset, zero,
tempo negativo e duração inválida. Não faça o clique depender da tira de
thumbnails já carregada.

**Verify:** testes de política passam sem Screen Recording, Accessibility ou
janela real.

### Step 2: Extrair o frame fora do MainActor e gravar PNG

Adicione o menor caminho concreto possível:

1. capture URL, tempo e um identificador de nome no MainActor;
2. crie `AVURLAsset`/`AVAssetImageGenerator` a partir da URL;
3. aplique a transformação preferida e gere o frame no tempo solicitado;
4. grave PNG em uma URL única sob o temp capture root ou no destino definido
   pelo caminho de screenshot;
5. retorne somente URL/tempo solicitado/tempo real em um valor Sendable;
6. se qualquer etapa falhar, remova somente o arquivo parcial criado e lance
   um erro localizado.

O `actualTime` deve ser usado para diagnóstico, não para deslocar o playhead.
Não bloqueie a UI com `copyCGImage` síncrono em um botão MainActor; se o SDK
exigir uma API síncrona, rode a operação em uma task não isolada segura e
aguarde seu resultado.

**Verify:** fixture de vídeo sintético gera PNG legível, tamanho não zero,
orientação correta e nenhum arquivo parcial após erro.

### Step 3: Reutilizar o pós-capture de screenshot e forçar Annotate explícito

Adicione ao `PostCaptureActionHandler` uma operação concreta para um frame
extraído, ou componha a operação existente sem duplicar as regras de History e
Quick Access.

- Execute as mesmas regras de screenshot para clipboard, save, Quick Access e
  History, quando aplicáveis.
- Como o usuário clicou explicitamente em “Anotar frame”, abra o Annotate
  mesmo quando a preferência global `openAnnotate` estiver desligada.
- Prefira `AnnotateManager.openAnnotation(for: item)` quando houver item de
  Quick Access; caso contrário use `openAnnotation(url:)`.
- Não abra duas janelas se a operação comum já abriu uma: centralize a decisão
  ou permita que o manager reutilize a janela existente, mas teste o resultado.
- Logue source filename, tempo solicitado e tempo real apenas no logger; não
  mostre paths internos nem crie um schema de contexto sem necessidade.

Se a política atual de save mover o PNG, mantenha a URL final retornada pelo
handler antes de abrir Annotate. Se uma ação opcional falhar, preserve uma
imagem temporária válida e informe o usuário sem perder o frame.

**Verify:** testes com fake de Quick Access/PostCapture provam que o frame é
tratado como screenshot e que a ação explícita abre Annotate sem alterar
`PreferencesAfterCaptureMatrix`.

### Step 4: Expor uma ação clara e acessível no editor

Coloque um botão compacto na toolbar de vídeo, visível apenas para vídeos
(`!state.isGIF`) e desabilitado enquanto a extração estiver em andamento.

- Use um símbolo de frame/annotation reconhecível, label localizada e
  `help`/accessibility hint explicando “extrair o frame atual para anotar”.
- Não use o ícone `camera` isolado, pois o editor já usa “camera” para o zoom
  virtual e o produto terá câmera PiP depois.
- Mostre progresso/estado mínimo (disabled + toast é suficiente); não adicione
  uma modal de exportação.
- O callback deve iniciar a task e manter o editor aberto; após sucesso, o
  Annotate pode se tornar a janela ativa.
- Em caso de falha, use o sistema de feedback existente e mantenha playhead,
  zoom selection e undo stack intactos.

**Verify:** build Video, inspeção visual da toolbar em light/dark, teclado/foco
e teste manual do clique com o playhead no início, meio e fim.

### Step 5: Cobrir regressões e documentar o limite

Adicione testes para:

- clamp e nome determinísticos;
- extração de frame no tempo solicitado e orientação de track;
- erro sem arquivo parcial;
- rota screenshot → Quick Access/History → Annotate;
- GIF sem ação;
- preferência `openAnnotate` permanecendo inalterada;
- arquivo original de vídeo não sendo modificado.

Atualize a documentação para dizer que “Anotar frame” cria um screenshot
independente; se o usuário precisar que zoom/background apareçam na imagem,
deve salvar/exportar o vídeo ou abrir um plano separado de composição.

**Verify:** rode todos os comandos da tabela e registre a checagem manual.

## Test plan

### XCTest obrigatório

- Teste puro de clamp/nome/request.
- Teste de extractor com asset sintético, incluindo orientação e falha.
- Teste do handler com fakes, sem abrir janelas reais, garantindo uma única
  decisão de Annotate e preservação do comportamento de screenshot.
- Teste de estado/toolbar para `isGIF`, `isExtracting` e ação desabilitada.

Não adicione testes que dependam de tempo de parede, cursor real ou permissões
de Screen Recording.

### Manual obrigatório depois da integração

1. Compile `Notinhas Video` e abra uma gravação real no Video Editor.
2. Scrub até um ponto conhecido, clique em **Anotar frame**, confirme que a
   imagem aberta corresponde ao ponto e que o vídeo original continua intacto.
3. Adicione pin, retângulo e nota no Annotate; copie/exporte e confirme que a
   saída é uma imagem estática normal do Notinhas.
4. Repita com `openAnnotate` desligado e com Quick Access desligado; a ação
   explícita ainda deve abrir o Annotate sem duplicar History/Quick Access.
5. Abra um GIF e confirme que a ação não aparece.

## Done criteria

- [ ] Um clique no playhead gera um PNG estático sem reencodar o vídeo.
- [ ] A geração ocorre fora do MainActor e não bloqueia a janela do editor.
- [ ] A transformação de orientação da track é respeitada.
- [ ] O frame passa pelo caminho existente de screenshot/Quick Access/History.
- [ ] A ação explícita abre o Annotate mesmo com `openAnnotate` global off.
- [ ] O usuário pode usar pins, retângulos, notas, clipboard e export atuais.
- [ ] Falhas não deixam arquivo parcial nem fecham o Video Editor.
- [ ] O frame bruto e o limite “sem efeitos renderizados” estão documentados.
- [ ] GIF, preferências existentes e scheme padrão não sofrem alteração.
- [ ] Testes focados, build/test Video, format, lint, agent-check e verify local
      passam ou registram baseline exato.

## STOP conditions

- A implementação precisa renderizar zoom/background/speed para cumprir a
  expectativa; pare e abra um plano de compositor de frame.
- A extração síncrona exige bloquear o MainActor ou copiar objetos AppKit não
  Sendable entre actors.
- A rota de screenshot cria dois History records, duas janelas Annotate ou
  perde o PNG ao mover para o destino.
- O botão depende de alterar a preferência global `openAnnotate`.
- O frame extraído contém pixels do próprio overlay/app sem que isso seja uma
  decisão explícita da captura original.
- Um gate determinístico falha duas vezes após correção razoável.

## External-state addendum

- **Authority:** o vídeo fonte é somente leitura; a imagem PNG gerada e o
  resultado do `PostCaptureActionHandler` são a autoridade do novo screenshot.
- **Identity:** URL única do PNG + associação normal de Quick Access/History;
  source URL e timestamps são contexto, não identidade do screenshot.
- **Scope:** somente o vídeo aberto pelo editor e a URL temporária/destino
  escolhida pelo fluxo atual de screenshot.
- **Preflight:** confirmar que source existe, que a URL temporária está sob o
  temp root e que o arquivo PNG foi fechado/validado antes de post-capture.
- **Idempotency:** cada clique pode criar um frame novo, mas uma única
  operação deve produzir no máximo um Quick Access item e um History record.
- **Failure:** erro de leitura/escrita preserva o vídeo e remove apenas o
  arquivo parcial criado pela tentativa.
- **Concurrency:** bloquear o segundo clique enquanto a extração corrente não
  terminou; callbacks tardios não podem abrir Annotate para uma tentativa
  cancelada.
- **Destructive actions:** nunca modificar ou apagar o vídeo fonte; cleanup só
  remove PNG parcial/temporário não promovido.

## Maintenance notes

- A referência de touchpoint é `Screendrop → Studio/playback` e a superfície
  alvo é `VideoEditor → Annotate`; a decisão é reimplementação independente.
- Se o uso real mostrar que frames anotados precisam voltar ao vídeo com tempo
  clicável, esse é um produto novo (anotação temporal) e não uma extensão
  silenciosa deste plano.
- Não duplicar `AVAssetImageGenerator` em Quick Access e Video Editor sem
  evidência de divergência; prefira um helper concreto compartilhado apenas
  quando houver dois callers reais.
