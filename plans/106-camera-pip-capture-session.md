# Plan 106: Capturar câmera PiP como track opcional e sincronizada

> **Instruções para o executor:** este plano adiciona somente a metade de
> captura/sessão da câmera PiP. O compositor e a UI de layout do editor ficam
> no plano 107. O resultado deste plano é um arquivo de gravação que contém
> uma track de câmera identificável, sincronizada com a tela, ou uma gravação
> de tela íntegra quando a câmera não puder iniciar.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat d894dea5..HEAD -- Notinhas/Features/Recording Notinhas/Services/Capture/ScreenRecordingManager.swift Notinhas/Services/Capture/RecordingMetadata.swift Notinhas/Features/Preferences Notinhas/Resources/Info.plist Notinhas/Resources/Info-Debug.plist Notinhas/Resources/*lproj/InfoPlist.strings NotinhasTests/Features/Recording NotinhasTests/Services/Capture`
>
> Execute depois do plano 104 ou, se necessário, faça cherry-pick somente do
> contrato de `RecordingSession`/stop sem integrar branches automaticamente.
> Use `.worktrees/camera-pip-capture-session` e branch
> `camera-pip-capture-session`. Merge/push não são autorizados.

## Status

- **Priority:** P1
- **Effort:** L
- **Risk:** HIGH
- **Depends on**: Plano 104 recomendado/serializado; o contrato de finish/recovery deve estar definido antes de adicionar uma track
- **Category:** feature / architecture
- **Planned at**: commit `d894dea5`, 2026-08-23 (after Plans 104–105 local integration)
- **Finding ID:** `camera-pip-capture-session`
- **Publication:** local plan
- **Integration:** branch isolada até revisão; merge local e push exigem autorização explícita

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `High/Full`
- **Parallelizable:** não com o plano 104 nem com mudanças em
  `RecordingSession`, `ScreenRecordingManager`, metadata ou toolbar; pode ser
  paralelo ao plano 105 se os arquivos do Video Editor não forem tocados
- **Reviewer required:** sim; AVFoundation capture, TCC, Sendable, timestamps,
  fallback e schema migration
- **Rationale:** câmera é hardware opcional e não pode colocar em risco o
  caminho principal de screen recording. Um capturer isolado, análogo ao mic,
  reduz a superfície de falha.
- **Escalate when:** o device não fornecer frames em host time compatível com
  ScreenCaptureKit; a track vazia tornar o writer inválido; ou a política de
  permissão exigir gravar/armazenar dados de device além do necessário para
  reabrir o editor.

## Why this matters

Uma câmera PiP pode tornar uma explicação de mudança de interface mais humana,
mas só serve ao Notinhas se continuar sendo uma camada da gravação de tela.
Screendrop e Capso demonstram a oportunidade visual; a implementação deve ser
independente e limitada ao handoff. Consulte
[Screendrop](https://github.com/fayazara/Screendrop) como referência CC0 de
camera + screen e [Capso](https://github.com/lzhgus/Capso) apenas como
referência comportamental sob BSL 1.1; não copie código/assets de nenhum dos
dois.

O requisito de produto é:

> uma câmera opcional, uma pessoa, uma gravação de tela, uma track sincronizada,
> uma posição inicial previsível e fallback screen-only.

Não é requisito criar câmera independente, streaming, várias câmeras,
background removal ou uma segunda ferramenta de videoconferência.

## Current state

- `RecordingCoordinator` resolve `captureMicrophone` e `microphoneDeviceID`
  da toolbar e chama `ScreenRecordingManager.prepareRecording(...)`; não há
  opção, device ou retry de câmera.
- `MicrophoneAudioCapturer.swift` já fornece o padrão local: capturer
  `nonisolated`, delegate de sample buffer, factory de sessão testável,
  permission check e integração independente ao `ScreenRecordingManager`.
- `RecordingSession` tem um input de vídeo de tela via pixel-buffer adaptor,
  dois inputs de áudio e a timeline baseada no primeiro frame de tela. Não há
  camera input, track role ou contador de camera.
- `ScreenRecordingManager` configura o writer em uma única saída, inicia mic
  separado e salva `RecordingMetadata` v5 somente para mouse/audio. A
  normalização de áudio deve preservar a track de câmera quando existir.
- `RecordingMetadata` possui `RecordingAudioSourceTrack` e `audioSourceTracks`,
  uma boa convenção para adicionar uma lista de roles de vídeo. Decodificação
  antiga precisa continuar funcionando quando novos campos não existirem.
- `RecordingToolbarWindow`/`RecordingToolbarState` têm toggles de microfone,
  áudio do sistema, formato, qualidade, cursor, clicks e keystrokes. O camera
  toggle deve começar desligado e ser escondido quando o módulo Video não está
  compilado.
- O projeto usa `PBXFileSystemSynchronizedRootGroup`; novos Swift files sob
  `Notinhas/` e `NotinhasTests/` entram automaticamente no target sincronizado.
  Ainda assim, confirme target membership no Xcode/build; não faça edição manual
  de `project.pbxproj` sem evidência de que o arquivo não foi incluído.
- `Info.plist` e `Info-Debug.plist` já têm `NSMicrophoneUsageDescription`, mas
  não têm `NSCameraUsageDescription` nem strings localizadas de câmera.
- `VideoModuleAvailability` e `videoModule.enabled` já são a fronteira de
  disponibilidade. Não crie `NOTINHAS_CAMERA_MODULE` nem uma segunda flag.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Capturer existente | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/Recording/MicrophoneAudioCapturerTests` | exit 0 |
| Configuração | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/Recording/RecordingConfigurationTests` | exit 0 |
| Sessão | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/Recording/RecordingSessionTests` | exit 0 |
| Metadata | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Format/lint | `make format-check && make lint-changed` | exit 0 |
| Build | `make build-video` | exit 0 |
| Tests | `make test-video` | exit 0 |
| Agent gate | `make agent-check` | exit 0 ou baseline exato |
| Verify map | `./scripts/verify-local.sh --base 6106c84 --full --plan-only --strict` | superfície coberta |

O teste real de câmera deve ser opt-in, por exemplo
`NOTINHAS_RUN_CAMERA_INTEGRATION=1`, seguindo o padrão já usado para microfone;
nunca ligue hardware no suite silencioso.

## Suggested toolkit

- `AVCaptureDevice.DiscoverySession`, `AVCaptureDeviceInput`,
  `AVCaptureVideoDataOutput`, `AVCaptureVideoPreviewLayer` e
  `AVCaptureSession` nativos.
- `AVCaptureVideoDataOutput` em `kCVPixelFormatType_32BGRA`, fila serial
  dedicada e `alwaysDiscardsLateVideoFrames = true` para evitar backlog.
- Pixel-buffer adaptor do `AVAssetWriter` existente, se a configuração de
  camera for compatível; não introduza um segundo encoder externo.
- `AVCaptureDevice.authorizationStatus(for: .video)` e
  `requestAccess(for: .video)` com mensagens localizadas.
- `CMSampleBufferGetPresentationTimeStamp` + o mesmo `CMTime`/pause offset da
  tela; não usar `Date()` para sincronizar tracks.
- Factory concreta testável copiada em espírito do mic, sem protocolo genérico
  de “media input” até existir um segundo consumidor real.

## Scope

**In scope:**

- `Notinhas/Features/Recording/CameraVideoCapturer.swift` e, se necessário,
  um provider concreto de devices/preview em `Features/Recording/`
- `Notinhas/Features/Recording/RecordingSession.swift`
- `Notinhas/Services/Capture/ScreenRecordingManager.swift`
- `Notinhas/Features/Recording/RecordingCoordinator.swift`
- `Notinhas/Features/Recording/RecordingToolbarWindow.swift`, toolbar/options
  e componentes de permission/device picker
- `Notinhas/Features/Preferences/Models/PreferencesKeys.swift`,
  `PreferencesCaptureSettingsView.swift` e importer/exporter somente para os
  dois valores de câmera necessários
- `Notinhas/Services/Capture/RecordingMetadata.swift`
- `Notinhas/Resources/Info.plist`, `Info-Debug.plist` e
  `InfoPlist.strings`/catalogs de localização correspondentes
- testes de capturer, configuração, sessão, metadata e routing
- `docs/RECORDING.md`, `docs/PREFERENCES.md` e/ou `docs/APP_LIFECYCLE.md`
  quando o contrato for alterado

**Out of scope:**

- compositor, preview final e controles de posição/resize no Video Editor
  (plano 107)
- câmera como fonte de áudio; o mic continua sendo o único áudio opcional
  separado
- múltiplas câmeras, captura em background, streaming, teleprompter,
  transcrição, filtros, remoção de fundo, auto-framing ou face tracking
- câmera-only recording, foto da webcam ou upload
- alterar qualidade/FPS padrão da tela ou remover o gate do Video module

## Git workflow

1. Crie `.worktrees/camera-pip-capture-session` a partir do commit-base e
   confirme que a integração do plano 104 está presente ou registrada como
   dependência não integrada.
2. Separe commits de capturer/TCC, writer/metadata e UI/localização.
3. Use somente `git add` de paths nomeados; não estagie o repositório inteiro.
4. Deixe branch/worktree para review; merge/push não estão autorizados.

## Steps

### Step 1: Definir configuração e fallback antes do hardware

Adicione os menores valores necessários:

- `PreferencesKeys.recordingCaptureCamera`, default `false`;
- `PreferencesKeys.recordingCameraDeviceID`, opcional e sem valor secreto;
- `RecordingToolbarPreferences.captureCamera(defaults:)` e provider de device
  selecionado;
- `RecordingCameraRequest`/configuração concreta contendo enabled, device ID,
  mirror/orientation e preset, se a API precisar;
- estado de resultado: `captured`, `unavailable`, `permissionDenied`,
  `deviceDisconnected`, `writerFailed` ou equivalente.

O valor persistido deve ser apenas preferência de ativação/device selecionado;
não persistir frames, thumbnails privadas ou dados biométricos.

Defina a regra de fallback: permission denied, device inexistente, formato
indisponível ou falha de setup desabilita somente a câmera e continua a
gravação de tela. Se a câmera foi explicitamente ligada, mostre uma confirmação
curta com “continuar sem câmera”/“abrir ajustes” sem abortar silenciosamente.

**Verify:** testes de defaults, device desaparecido e resolução de request
passam no scheme Video; o scheme padrão não referencia os novos símbolos.

### Step 2: Implementar `CameraVideoCapturer` isolado

Reutilize a forma de `MicrophoneAudioCapturer`, mas não o force a compartilhar
uma abstração prematura.

- descobrir cameras externas/built-in com `DiscoverySession` determinística;
- escolher o device persistido se ainda existir, senão o default estável;
- pedir TCC somente quando o usuário ativar camera ou iniciar uma gravação
  com camera ligada;
- configurar `AVCaptureSession`/input/output em fila própria;
- limitar a resolução a um formato razoável para PiP (não selecionar 4K apenas
  porque está disponível) e preferir 30 fps compatível com o recording FPS;
- entregar sample buffers via delegate não isolado e fornecer preview layer
  opcional para a UI;
- observar interrupção, device removal e runtime error; parar somente câmera
  e devolver uma disposição de downgrade;
- parar/remover delegate/session exatamente uma vez.

Não inicie captura de camera durante a seleção se o toggle estiver desligado.
O preview, quando ligado, deve ser uma janela/NSView que o fluxo de exclusão
do Notinhas não inclua na área gravada.

**Verify:** unit tests com factory fake cobrem autorização, input, output,
start/stop, delegate e erro; teste real permanece opt-in.

### Step 3: Integrar a camera ao writer sem criar uma segunda timeline

Estenda `RecordingSession` com um input de vídeo de camera e pixel-buffer
adaptor somente quando a configuração foi resolvida com sucesso.

- a primeira amostra de tela continua estabelecendo o início da sessão;
- amostras de câmera que chegam antes da tela são descartadas ou aguardam uma
  janela pequena, nunca criam um segundo `firstTimestamp`;
- camera, screen, system audio e mic usam o mesmo `pauseOffsetAccumulator`;
- durante pause, camera não deve continuar avançando a timeline; ao resume,
  os frames usam o mesmo offset que a tela;
- camera append failure marca a camera como indisponível e não falha o writer
  de tela; screen/system/mic continuam;
- a barreira append/finish do plano 104 cobre também camera;
- mantenha contadores separados (received/appended/dropped/failed) para
  diagnóstico sem incluir dados sensíveis.

Se o pixel-buffer adaptor não aceitar o formato escolhido, ajuste o output
  para BGRA ou abandone a camera antes de iniciar o writer. Não converta cada
  frame com uma cadeia CIImage pesada sem medir.

**Verify:** testes com timestamps sintéticos provam que screen/camera/audio
  têm o mesmo primeiro tempo, que pause não cria gap e que falha de camera
  produz screen-only válido.

### Step 4: Versionar metadata e preservar a track após normalização

Adicione campos opcionais ao `RecordingMetadata`, elevando a versão somente
quando a mudança for necessária. Um formato mínimo é:

- `RecordingVideoSourceTrack { trackID, role: screen|camera, captureSize,
  isMirrored }`;
- `videoSourceTracks: [RecordingVideoSourceTrack]`;
- `cameraDisposition` opcional para explicar downgrade sem guardar device
  serial/ID sensível.

Regras:

- decoder v1–v5 preenche arrays vazios e interpreta a gravação como screen-only;
- encoder omite campos vazios para manter JSON pequeno e compatível;
- depois de stop/normalização, inspecione o arquivo final/editor source e salve
  o track ID efetivo; não presuma que o ID do writer sobrevive a um export;
- se `RecordingAudioCompatibilityExporter` criar uma fonte para o editor,
  confirme que todos os video tracks são preservados e que a resolução de role
  ainda funciona;
- `RecordingMetadataStore` move/delete/orphan cleanup deve tratar os novos
  campos como metadata, nunca como mídia independente.

**Verify:** round-trip v5, round-trip camera, downgrade sem camera track,
track ID incorreto após normalização e move de metadata para URL nova.

### Step 5: Expor toggle, device e permission copy com o menor UI possível

Na pre-record toolbar:

- adicione um toggle camera desligado por default;
- mostre picker de device somente quando camera está ligada ou no menu de
  opções; exiba “câmera indisponível” sem quebrar o menu;
- preview compacto é opcional à ativação e deve ter label, foco e tamanho
  mínimo; não faça preview fullscreen;
- camera deve ficar desabilitada em GIF output, pois o plano 107 trata somente
  vídeo multi-track;
- durante a gravação, não exiba a janela de preview dentro da região capturada;
  use a mesma configuração de exclusão de janelas do recording flow.

Adicione `NSCameraUsageDescription` em `Info.plist` e `Info-Debug.plist` e
strings localizadas coerentes com o texto de microfone. Reveja o copy com a
skill de UX writing e a acessibilidade nativa antes do commit.

**Verify:** light/dark, VoiceOver/keyboard, toggle on/off, câmera removida,
permission denied e gravação de área próxima à toolbar.

### Step 6: Integrar stop/restart/cancel e validar o vertical slice

Passe `captureCamera`/device da toolbar ao `prepareRecording` e ao retry. O
retry deve preservar o mesmo comportamento do mic:

- retry sem camera nunca reinicia a tela automaticamente se ela já está
  gravando;
- restart cria uma nova sessão com o request atual;
- cancel remove camera resources e segue o cancelamento do writer;
- stop salva metadata somente após o resultado do writer e normalização;
- cleanup remove preview/session/delegate sem deixar a câmera aberta.

Atualize docs com permissão, default off, fallback e metadata de role. Rode
testes focados, build/test Video, format, lint, agent-check e verify map.

**Verify:** a integração do plano 104 continua verde e nenhum caminho de
  `Notinhas` sem `NOTINHAS_VIDEO_MODULE` conhece AVFoundation camera.

## Test plan

### XCTest obrigatório

- `CameraVideoCapturerTests`: factory fake, autorização, device ID,
  configuração, sample delegate, stop idempotente e runtime failure.
- `RecordingConfigurationTests`: default off, persistência de device e GIF
  incompatível.
- `RecordingSessionTests`: timestamps screen/camera/audio, pause/resume,
  camera unavailable, append failure isolado e finalização.
- `RecordingMetadataStoreTests`: v5 decode, nova versão encode/decode,
  role/track ID e move/delete.
- routing/availability tests: compile/runtime gate e permission state.

### Manual obrigatório depois da integração

1. No macOS, compile `Notinhas Video`, habilite o módulo em Preferences →
   Advanced e conceda Camera/Screen Recording; conceda Microphone apenas se
   selecionado.
2. Grave com camera off e confirme que o vídeo existente permanece idêntico em
   comportamento/timeline.
3. Grave com camera on, device default e device externo; confirme que a tela e
   a camera têm duração alinhada, sem frame anterior ao início.
4. Pause/resuma, pare, reabra o asset e confirme que a metadata identifica a
   camera; o posicionamento visual será validado no plano 107.
5. Revogue/negue Camera antes de iniciar e confirme que a tela grava sozinha.
6. Desconecte a câmera durante a gravação; confirme downgrade screen-only e
   ausência de crash.
7. Escolha GIF e confirme que camera não é iniciada.
8. Feche o app enquanto grava e execute também os gates de recuperação do plano
   104.

## Done criteria

- [ ] Camera é opt-in, compilada/runtime-gated pelo módulo Video existente.
- [ ] TCC, device picker, preview e copy estão localizados e acessíveis.
- [ ] Camera é uma track identificável, não uma imagem baked durante capture.
- [ ] Screen, camera e áudio compartilham o mesmo relógio/pausa.
- [ ] Permission/device/writer failure degrada para screen-only sem perder a
      gravação principal.
- [ ] Stop/restart/cancel/termination fecham camera resources uma vez.
- [ ] Metadata nova é retrocompatível com v5 e preserva role após normalização.
- [ ] O scheme padrão compila sem camera code e sem prompt de Camera por
      caminho não utilizado.
- [ ] Testes focados, build/test Video, format, lint, agent-check e verify local
      passam ou registram baseline exato.
- [ ] Manual Camera/Screen Recording/WindowServer foi executado e registrado.

## STOP conditions

- A camera cria um segundo relógio, usa `Date()` para sincronização ou reabre
  gaps de pause já corrigidos.
- Falha de camera aborta/invalidates a track de tela ou faz o usuário perder o
  arquivo principal.
- A única solução funcional é adicionar uma dependência externa, um segundo
  feature flag ou um encoder paralelo.
- O preview pode ser incluído na região capturada ou não tem exclusão
  determinística.
- Metadata antiga não decodifica, track IDs mudam sem fallback seguro ou a
  normalização elimina a câmera sem marcar downgrade.
- A permissão de Camera é pedida no launch/default scheme sem ação explícita.
- Um gate determinístico falha duas vezes após correção razoável.

## External-state addendum

- **Authority:** o request da sessão é a autoridade de ativação durante a
  gravação; UserDefaults só fornece default antes do start; metadata final
  descreve o que realmente foi capturado.
- **Identity:** sessão UUID + role de track; device ID serve apenas para
  seleção local e não é requisito de reabertura.
- **Scope:** câmera escolhida pelo usuário, processing directory da sessão,
  arquivo final e metadata associada àquele arquivo.
- **Preflight:** permission status, device conectado, format/pixel format,
  writer input disponível e exclusão da janela preview antes do start.
- **Idempotency:** start/stop/permission callback/device removal não podem
  adicionar duas inputs, dois delegates ou duas tracks de camera.
- **Failure:** denied/unavailable/disconnected/writer append failure preservam
  screen-only e registram disposition; não armazenam frames fora da sessão.
- **Concurrency:** sample delegate, stop, pause e device runtime error passam
  por uma única fronteira de sessão; UI não toca writer diretamente.
- **Destructive actions:** cancel remove somente recursos/artefatos da sessão
  corrente; nunca remove device preference ou mídia histórica sem ação do
  usuário.

### High-risk traceability

| Invariante | Implementação | Evidência |
| --- | --- | --- |
| uma timeline para screen/camera/audio | `RecordingSession` com primeiro timestamp de tela e pause offset único | testes de PTS/pause multi-track |
| camera opcional não derruba tela | capturer disposition + camera input isolado | teste permission/disconnect + manual downgrade |
| role sobrevive ao save | `RecordingMetadata` v6 + inspeção do asset final | round-trip/move/normalization tests |
| preview não entra na gravação | window exclusion do recording flow | manual área/toolbar + teste de configuração |
| sem camera no default | `#if NOTINHAS_VIDEO_MODULE` + runtime availability | default build + availability tests |

## Maintenance notes

- A track de camera é uma fonte de edição, não uma promessa de layout; o plano
  107 deve consumir `role`/ID e manter screen-only fast path.
- Não persistir `AVCaptureDevice.uniqueID` como dado necessário para abrir o
  vídeo; se for útil para diagnóstico, redija ou descarte.
- A resolução inicial pode ser conservadora. Só aumentar qualidade/FPS após
  medir tamanho/CPU em gravações reais.
- Se a saída do writer com duas video tracks não for estável, pare antes de
  inventar uma composição durante a captura; o plano 107 pode trabalhar com
  masters separados somente mediante novo contrato e revisão.
