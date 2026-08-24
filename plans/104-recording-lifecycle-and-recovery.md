# Plan 104: Tornar a gravação recuperável em falha, encerramento e writer incompleto

> **Instruções para o executor:** leia este plano inteiro antes de editar. A
> entrega é uma garantia observável de “finalizar ou preservar” uma gravação;
> não transforme o trabalho em uma reescrita do módulo Video. Preserve o
> limite compile-time/runtime existente (`NOTINHAS_VIDEO_MODULE` +
> `VideoModuleAvailability`) e todos os invariantes de timestamp já cobertos
> por `docs/RECORDING.md`.
>
> **Drift check (execute primeiro):**
> `git status -sb && git diff --stat 6106c84..HEAD -- Notinhas/Features/Recording/RecordingSession.swift Notinhas/Services/Capture/ScreenRecordingManager.swift Notinhas/Services/Capture/TempCaptureManager.swift Notinhas/App/AppCoordinator.swift Notinhas/App/NotinhasApp.swift NotinhasTests/Features/Recording NotinhasTests/Services/Capture`
>
> Se o commit-base não for ancestral ou houver alterações locais nesses
> caminhos, pare, registre o conflito e reconcilie o plano antes de tocar nos
> arquivos. A implementação deve ocorrer em `.worktrees/<slug>` com branch
> lowercase-kebab-case, conforme `core/policies/worktrees.md`; merge e push
> não estão autorizados por este plano.

## Status

- **Priority:** P0
- **Effort:** L
- **Risk:** HIGH
- **Depends on**: —; executar antes dos planos de câmera PiP
- **Category:** correctness / architecture / perf
- **Planned at**: commit `6106c84`, 2026-08-23
- **Finding ID:** `recording-lifecycle-recovery`
- **Publication:** local plan
- **Integration:** somente branch de implementação até revisão; merge local e push exigem autorização explícita

## Execution profile

- **Recommended profile:** `implementer`
- **Risk/lane:** `High/Full`
- **Parallelizable:** não; `RecordingSession`, `ScreenRecordingManager` e o
  ciclo de vida do app são uma única fronteira de serialização
- **Reviewer required:** sim; revisão de AVFoundation, concorrência, perda de
  dados e fechamento do app
- **Rationale:** o problema atual não é apenas uma opção de encoding. Stop,
  cancelamento, encerramento, limpeza, metadata e Quick Access precisam
  concordar sobre o resultado final da sessão.
- **Escalate when:** a API de encerramento não puder aguardar finalização de
  forma limitada; a saída fragmentada não for reproduzível no SDK/container
  atual; ou a recuperação exigir apagar, substituir ou migrar mídia do usuário
  sem uma política explícita.

## Why this matters

O Screendrop é uma boa referência de engenharia porque trata a gravação como
uma sessão que pode falhar sem simplesmente desaparecer. No Notinhas, quatro
lacunas tornam o fluxo capture → annotate → clipboard frágil:

- `RecordingSession` registra falhas de append e de `finishWriting()` em logs,
  mas o chamador não recebe um resultado tipado de sucesso, falha ou parcial.
- `finishInputs()` pode concorrer com um append que já saiu do `NSLock`, criando
  uma janela de corrida exatamente no fim da gravação.
- `ScreenRecordingManager.stopRecording()` normaliza, salva metadata e move o
  arquivo depois de `finishWriting()`, mas o delegate de terminação do app não
  chama esse caminho.
- `TempCaptureManager.cleanupOrphanedFiles()` conhece arquivos temporários e
  histórico, mas não distingue uma sessão de gravação abandonada de um órfão
  seguro para apagar.

O resultado desejado é simples: uma sessão normal termina como vídeo válido; uma
falha preserva um artefato recuperável ou mostra falha explícita; encerramento
gracioso usa o mesmo caminho; morte abrupta deixa uma sessão identificável para
avaliação no próximo launch.

## Current state

- `Notinhas/Features/Recording/RecordingSession.swift` é `@unchecked Sendable`,
  mantém `AVAssetWriter`, inputs e contadores sob `NSLock`, inicia no primeiro
  frame de tela e aplica `pauseOffsetAccumulator` a vídeo, system audio e mic.
  Esses invariantes devem permanecer.
- Em `RecordingSession.appendVideoSample`, `appendAudioSample` e
  `appendMicrophoneSample`, a leitura de readiness ocorre sob lock, mas o
  `append` efetivo ocorre depois; `finishInputs()` marca inputs terminados sob o
  lock. O plano deve fechar essa fronteira sem fazer logging/callback bloqueante
  dentro do lock.
- `RecordingSession.finishWriting()` aguarda `finishWriting()` do writer e
  apenas registra `writer.error`; não retorna um status utilizável.
- `ScreenRecordingManager.RecordingState` tem apenas `idle`, `preparing`,
  `recording`, `paused` e `stopping`. `stopRecording()` em torno de
  `ScreenRecordingManager.swift:1201–1290` sempre continua para normalização,
  metadata e `finalizeRecordingOutput` depois do finish.
- `TempCaptureManager.makeRecordingSavePlan()` cria um diretório de processing
  por UUID; `makeRecoveredRecordingURL(for:)` já existe para falha de move
  após stop. Isso é reutilização obrigatória para o primeiro caminho de
  recuperação.
- `AppCoordinator.applicationWillTerminate()` e o delegate em
  `NotinhasApp.swift` encerram observadores/configuração, mas não finalizam um
  recorder ativo. Não há no repositório uma atividade `beginActivity`, uma
  proteção específica contra idle sleep ou um manifest de sessão abandonada.
- A normalização de áudio em `RecordingAudioCompatibilityExporter` pode gerar
  uma fonte de editor separada. Qualquer mudança no writer deve preservar todos
  os tracks existentes e os `RecordingMetadata` v5 atuais.
- O módulo Video é opcional. O scheme padrão `Notinhas` deve continuar
  compilando sem os símbolos protegidos por `#if NOTINHAS_VIDEO_MODULE`.

## Commands you will need

| Propósito | Comando | Resultado esperado |
| --- | --- | --- |
| Baseline de estado | `git status -sb` | confirma branch, base e alterações não relacionadas |
| Sessão | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Features/Recording/RecordingSessionTests` | exit 0 |
| Processing/recovery | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/TempCaptureManagerTests` | exit 0 |
| Metadata | `./scripts/run-tests.sh --video-module -only-testing:NotinhasTests/Services/Capture/RecordingMetadataStoreTests` | exit 0 |
| Formato | `make format-check` | exit 0 |
| Lint Swift alterado | `make lint-changed` | exit 0 |
| Build do módulo | `make build-video` | exit 0 |
| Testes do módulo | `make test-video` | exit 0 |
| Gate do agente | `make agent-check` | exit 0 ou falha-base exata registrada |
| Verificação por mapa | `./scripts/verify-local.sh --base 6106c84 --full --plan-only --strict` | superfície alterada coberta |

Durante a implementação, se o commit-base mudar, substitua `6106c84` pelo
SHA efetivamente verificado e registre a troca no handoff. Não rode o comando
`clean-build` como rotina: ele remove artefatos locais e não prova o problema.

## Suggested toolkit

- AVFoundation nativo: `AVAssetWriter.status`, `error`, `AVAsset`,
  `AVAssetReader`/`load(.duration)` e `movieFragmentInterval` somente se o SDK
  local confirmar a propriedade e a saída for validada.
- `NSLock` existente ou uma fila serial mínima para a operação indivisível
  “verificar readiness → append”; não crie um protocolo/factory para um único
  writer.
- `ProcessInfo.processInfo.beginActivity(options:reason:)` com token guardado
  por sessão e encerrado exatamente uma vez.
- `FileManager` + `Codable` + `.atomic` para um manifest pequeno; reutilize
  `TempCaptureManager`, `RecordingMetadataStore` e os helpers de logging.
- `Task`/`withTaskCancellationHandler` apenas onde ajudarem o fechamento
  limitado; não bloqueie o MainActor esperando indefinidamente o writer.

## Scope

**In scope:**

- `Notinhas/Features/Recording/RecordingSession.swift`
- `Notinhas/Services/Capture/ScreenRecordingManager.swift`
- `Notinhas/Services/Capture/TempCaptureManager.swift`
- `Notinhas/App/AppCoordinator.swift`
- `Notinhas/App/NotinhasApp.swift`
- `Notinhas/Features/Recording/RecordingCoordinator.swift` apenas para
  apresentar/rotear um resultado explícito de stop ou recuperação, se necessário
- testes correspondentes em `NotinhasTests/Features/Recording/` e
  `NotinhasTests/Services/Capture/`
- `docs/RECORDING.md` somente para documentar o contrato finalizado/preservado

**Out of scope:**

- câmera PiP, compositor multi-track ou alterações no Video Editor (planos
  106–107)
- frame-to-brief e abertura do Annotate (plano 105)
- cloud, upload, transcrição, teleprompter, streaming ou captura de câmera
  independente
- mudar codec, FPS, qualidade padrão, scheme padrão ou o modelo de pausa já
  documentado
- apagar automaticamente uma sessão abandonada apenas porque ela é antiga

## Git workflow

1. Crie o worktree obrigatório em `.worktrees/recording-lifecycle-recovery` e
   branch `recording-lifecycle-recovery` a partir do SHA verificado.
2. Faça commits pequenos e nomeados por superfície; não inclua alterações de
   `docs/REFERENCES.md` ou do overlay de benchmarking neste branch.
3. Rode os testes focados após cada mudança de contrato e os gates completos ao
   final.
4. Deixe branch e worktree para o revisor. Não faça merge, push, reset, clean
   ou remoção sem autorização explícita.

## Steps

### Step 1: Fixar a caracterização e o contrato de resultados

Antes de alterar o writer, rode os testes focados e leia os callers de
`stopRecording()`, `cancelRecording()`, `cleanup()`, `finalizeRecordingOutput`
e `RecordingCoordinator.stopRecording`. Registre os estados observáveis atuais.

Adicione testes determinísticos para:

- stop sem writer, writer com erro e writer finalizado;
- cancelamento não promovendo arquivo para Quick Access/History;
- pausa/resume mantendo o primeiro timestamp de vídeo e removendo o gap de
  áudio já documentado;
- stop repetido sendo idempotente.

Se for necessário um seam de teste, prefira uma função/closure concreta local
ou um writer de fixture; não introduza uma hierarquia de protocolos para
`AVAssetWriter`.

**Verify:** os testes novos falham pela ausência do comportamento antes da
implementação e os testes de timestamp existentes continuam verdes.

### Step 2: Serializar append e finish no mesmo limite

Altere `RecordingSession` para que vídeo, system audio, microphone audio e
camera futura possam usar o mesmo contrato: nenhum `markAsFinished()` pode
executar enquanto um append daquele input está em voo.

- Mantenha readiness/backpressure e contadores existentes.
- Faça o mínimo necessário para proteger a chamada de append; não segure lock
  durante callbacks, `DiagnosticLogger` ou `onFirstVideoFrame`.
- Faça `finishInputs()` impedir novas entradas, aguardar o append corrente e
  marcar cada input uma vez.
- Faça `cancelWriting()` reutilizar a mesma barreira sem tentar “finalizar com
  sucesso”.

**Verify:** teste de stop concorrente com append, teste de append depois de
  finish, e `RecordingSessionTests` passam sem exigir sleeps de parede.

### Step 3: Propagar um resultado de finalização confiável

Crie o menor tipo concreto necessário, por exemplo um resultado interno com
`finished`, `failed(error:)`, `missingWriter` e, se validado pelo recovery,
`preservedPartial(url:)`. O nome pode variar, mas o significado deve ser
explícito.

- `finishWriting()` deve devolver status/error do writer, não apenas logar.
- `stopRecording()` deve validar a saída antes de chamar normalização, metadata,
  Quick Access ou History.
- Um arquivo existente não é automaticamente “sucesso”: valide que é legível,
  tem duração positiva e contém a trilha de vídeo esperada.
- Preserve o arquivo de processing quando a saída é recuperável; só promova
  uma URL para o fluxo normal quando a validação passar.
- Mantenha a assinatura pública compatível se isso evitar uma cascata: um
  wrapper pode continuar retornando `URL?`, desde que o caminho interno não
  esconda o resultado e o coordinator trate falha/partial separadamente.

**Verify:** um writer falho não cria item normal de History/Quick Access; um
vídeo válido continua passando por normalização, metadata e clipboard como
antes; cancelamento não é confundido com falha.

### Step 4: Proteger o período de gravação e o encerramento normal

Adicione uma atividade por sessão, iniciada somente quando o capture stream e o
writer estiverem efetivamente ativos, e terminada depois de stop/cancelamento,
incluindo erros. A atividade deve ser idempotente e não vazar para sessões
seguintes.

Integre o encerramento do app:

- crie um método idempotente no recorder, como `finishForApplicationTermination`,
  que reutiliza o caminho “finish or preserve”;
- o delegate deve aguardar uma janela limitada e responder à terminação sem
  deixar o MainActor preso indefinidamente;
- se a janela acabar, marque o manifest como `abandoned` e preserve o diretório
  de processing; não apague nem mova uma mídia ainda possivelmente em escrita;
- o encerramento deve tolerar o recorder já estar `idle`, `stopping` ou ter
  terminado por erro.

Não use `exit`, `kill`, `sleep` ou uma thread global para mascarar a ordem de
shutdown. O caminho de cancelamento voluntário continua removendo apenas o
artefato explicitamente cancelado.

**Verify:** teste de delegate com recorder idle/recording/stopping, contagem de
  begin/end da atividade e teste de terminação limitada. Faça a checagem manual
  descrita em **Test plan**; não transforme o teste destrutivo em comando
  automático do agente.

### Step 5: Tornar a sessão de processing identificável e recuperável

Ao criar o diretório em `TempCaptureManager`, grave um manifest pequeno e
atômico com UUID, URLs internas relativas, container/codec, dimensões, data de
início, estado, último checkpoint e se a sessão foi finalizada. Atualize-o nos
limites de prepare/start/pause/resume/stop/abandon.

Na inicialização:

- enumere somente diretórios sob `recordingProcessingDirectory`;
- ignore manifests de sessões ainda ativas somente se houver uma indicação
  inequívoca de que o processo atual é o dono;
- valide a saída com AVFoundation antes de promover qualquer arquivo;
- para uma saída finalizável, use `makeRecoveredRecordingURL(for:)` e o fluxo
  existente de temp capture/metadata;
- para uma saída não finalizável mas preservável, mantenha o diretório e
  apresente estado de recuperação explícito, sem adicioná-lo como vídeo normal;
- só delete um diretório depois de sucesso de promoção, cancelamento explícito
  ou uma política de retenção comprovadamente segura.

Se `movieFragmentInterval` funcionar no SDK/container atual, configure um
intervalo conservador (o Screendrop usa cerca de 2 s como referência), valide
que o arquivo em andamento e o arquivo final são legíveis e registre essa
decisão no manifest. Se a saída fragmentada não for reproduzível com o codec,
container, normalização de áudio e export atual, **não** faça rotação ou
stitching especulativo: entregue primeiro o manifest + preservação do writer
único e documente a evidência para um plano posterior.

**Verify:** fixture de diretório abandonado, fixture de arquivo válido, fixture
de arquivo inválido, cleanup que não remove manifest ativo e cleanup que não
remove arquivo com History. `TempCaptureManagerTests` deve provar a política
sem depender do diretório real do usuário.

### Step 6: Integrar a superfície do produto e rodar gates

Mostre uma mensagem curta e acionável para falha/recuperação; não exponha
paths internos, UUIDs ou erros técnicos completos. Reutilize strings de
Recording e mantenha localização/acessibilidade para estados de recuperação.

Atualize `docs/RECORDING.md` com:

- estado normal, cancelado, falho e recuperável;
- localização conceitual do processing manifest;
- política de não apagar uma sessão abandonada antes da validação.

Rode os comandos focados, `make format-check`, `make lint-changed`,
`make build-video`, `make test-video`, `make agent-check` e a verificação por
mapa. Registre falhas de baseline com classificação conforme
`delivery-contract`; depois de duas falhas determinísticas iguais, pare.

**Verify:** todas as saídas do handoff registram comando, resultado e SHA.

## Test plan

### XCTest obrigatório

- `RecordingSessionTests`: serialização append/finish, resultado tipado,
  pause-offset, áudio antes do primeiro frame, cancelamento e idempotência.
- `TempCaptureManagerTests`: manifest, diretório abandonado, validação,
  promoção, retenção e proteção contra path fora do processing root.
- `RecordingMetadataStoreTests`: metadata atual v5 permanece legível e uma
  sessão recuperada não perde associação ao mover o arquivo.
- `RecordingCoordinator`/lifecycle tests: stop normal, stop repetido e
  encerramento com recorder idle/active, usando seams determinísticos.

### Manual obrigatório depois da integração

1. Compile `Notinhas Video` e conceda Screen Recording; conceda Microphone
   somente se a opção estiver ativa.
2. Grave uma captura de pelo menos dois minutos, pause/resuma várias vezes,
   pare e abra em Quick Access/History/Video Editor.
3. Inicie outra gravação e escolha Quit enquanto ela está ativa; confirme que o
   app encerra sem travar e que o resultado válido aparece ou a sessão é
   identificada para recuperação no próximo launch.
4. Repita com uma falha de writer simulada no seam de teste, não sobrescrevendo
   mídia do usuário.
5. Confirme que uma gravação normal ainda copia o vídeo para o clipboard e que
   o scheme padrão continua sem Recording/Video Editor.

Screen Recording, Accessibility e janela/WindowServer são gates manuais; não
   declare esses itens provados por XCTest silencioso.

## Done criteria

- [ ] Append e finalização de cada input são serializados; não há corrida
      stop-vs-append reproduzível.
- [ ] `finishWriting()` e `stopRecording()` distinguem sucesso, cancelamento,
      falha e resultado preservável.
- [ ] Writer inválido não é promovido silenciosamente a Quick Access/History.
- [ ] O caminho de terminação é idempotente, limitado e reutiliza o contrato
      normal de finalização.
- [ ] A atividade de prevenção de idle sleep começa/termina uma vez por sessão.
- [ ] Processing manifests são atômicos, versionáveis e não expõem paths ao
      usuário.
- [ ] Sessões abandonadas não são apagadas antes de validação/retention;
      arquivos recuperáveis seguem o caminho existente de temp capture.
- [ ] A decisão sobre `movieFragmentInterval` tem teste/evidência; sem
      compatibilidade, o plano registra o stop e não adiciona stitching.
- [ ] Gravações existentes, metadata v5 e o scheme padrão permanecem
      compatíveis.
- [ ] Testes focados, build/test do Video, format, lint, agent-check e verify
      local passam ou registram falhas de baseline exatas.
- [ ] Mudanças estão limitadas ao escopo deste plano.

## STOP conditions

- A correção exige alterar o contrato de pausa/timestamps sem um teste de
  regressão correspondente.
- `finishInputs()` ainda pode concorrer com append depois da mudança.
- O app pode terminar enquanto uma task de finalização mantém referências a
  uma sessão que já foi substituída por outra.
- A recuperação não consegue distinguir sessão ativa, abandonada, válida e
  inválida sem apagar ou sobrescrever mídia.
- A saída fragmentada produz arquivos que o editor/normalizador não consegue
  abrir; neste caso, pare a parte de fragmentação e entregue apenas a garantia
  de lifecycle/preservação documentada.
- Um teste de dados antigos falha ou o scheme padrão passa a compilar código do
  módulo Video.
- Qualquer gate determinístico falha duas vezes após uma correção razoável.

## External-state addendum

- **Authority:** o manifest da sessão descreve o estado de capture em
  processing; depois da promoção, o arquivo promovido + `RecordingMetadataStore`
  + History são a autoridade do artefato entregue.
- **Identity:** UUID da sessão e URLs sempre limitadas ao diretório criado por
  `TempCaptureManager`; associação final validada por URL/bookmark existente.
- **Scope:** somente diretórios sob `recordingProcessingDirectory`, o temp
  capture root e o arquivo final explicitamente escolhido pelo fluxo atual.
- **Preflight:** confirmar owner/estado do manifest, existência do arquivo,
  sandbox access, History record e validade AVFoundation imediatamente antes de
  mover ou apagar.
- **Idempotency:** checkpoints e promoção devem ser seguros para repetição;
  uma URL já promovida não deve gerar segundo History record.
- **Failure:** erro de writer, timeout, cancelamento, arquivo inválido e
  metadata corrompida preservam o máximo possível e deixam diagnóstico
  acionável; não caem em cleanup silencioso.
- **Concurrency:** uma sessão possui um único owner; stop, cancel, termination e
  startup recovery não podem operar simultaneamente no mesmo UUID.
- **Destructive actions:** apagar somente após cancelamento explícito, promoção
  confirmada ou retenção segura; nunca usar glob/recursion fora dos roots
  validados.

### High-risk traceability

| Invariante | Implementação | Evidência |
| --- | --- | --- |
| append não concorre com finish | `RecordingSession` writer boundary | teste stop-vs-append + `RecordingSessionTests` |
| writer inválido não vira sucesso | resultado tipado + validação AVFoundation | teste de erro + teste de saída válida |
| terminação não perde sessão silenciosamente | `finishForApplicationTermination` + manifest | lifecycle test + manual Quit |
| órfão não é apagado antes de análise | `TempCaptureManager` recovery scan | fixtures de manifest/cleanup |
| pausa preserva timeline | mesma subtração de pause offset em todas as tracks | testes de PTS existentes + novos testes |

## Maintenance notes

- O contrato importante é **finish or preserve**, não “sempre produzir um
  vídeo”. Falha explícita é melhor que um arquivo aparentemente válido.
- Não adicione uma segunda máquina de estados para fragmentos; o manifest deve
  refletir o estado da sessão que já existe.
- `movieFragmentInterval` é uma otimização de recuperação, não uma promessa de
  tamanho de arquivo. Reabra a decisão com métricas de sessões longas reais.
- A câmera PiP deve consumir o limite de writer/termination estabelecido aqui;
  não crie uma política de shutdown paralela no plano 106.
