# Plan 017: Build a reusable Arc-like overlay-tooltip component (floating window + keycaps)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat f125844..HEAD -- Snapzy/Shared/Components/KeyCapView.swift Snapzy/Services/Diagnostics/AppToastManager.swift`
> If either file changed since this plan was written, compare the "Current
> state" excerpts against the live code before proceeding; on a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: dx (UI component / discoverability)
- **Planned at**: commit `f125844`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — plans 018 and 019 both depend on the API this plan creates; it must land first.
- **Reviewer required**: `yes` — introduces a new AppKit `NSPanel` overlay + SwiftUI↔AppKit bridging (coordinate conversion, hover lifecycle); a reviewer should confirm no window-level or main-actor regressions.
- **Rationale**: New floating-window infrastructure and SwiftUI/AppKit interop are error-prone; the pure placement math is unit-tested to de-risk the trickiest part, but the presenter and hover lifecycle need judgment.
- **Escalate when**: the maintainer wants this tooltip adopted app-wide (every `.help(...)` replaced) — that is a much larger migration and leaves the Notinhas scope; reclassify.

## Why this matters

The recent shortcut-hint work (plans 015/016, shipped in commits `a2eaadb`,
`51ab0aa`, `f125844`) fell short of the intended visual: macOS `.help(...)`
renders only a plain, unstyled system tooltip, so keyboard shortcuts show as
parenthetical text like `Save (⌘⏎)`, and the only styled keycaps
(`KeyCapGroupView`) had to be pinned permanently inline next to the Save button,
cluttering the editor footer. The maintainer wants the Arc-browser behavior: on
hover, a single floating rounded bubble appears containing descriptive text plus
the shortcut rendered as little keycaps, and it disappears on mouse-out. That is
impossible with `.help(...)`, so this plan builds a dedicated, reusable overlay
tooltip — a borderless floating window hosting a SwiftUI bubble — that later
plans attach to the Notinhas note tool button (018) and note editor footer
(019). This plan ships only the component and its tests; the visible payoff
arrives when 018/019 attach it.

## Current state

- **Component to reuse (do NOT modify)** — the app already ships a keycap pill.
  The new bubble renders these directly (Arc shows keycaps side by side with no
  `+` separator, so lay out `KeyCapView` instances directly rather than using
  `KeyCapGroupView`, which inserts `+`):

```11:50:Snapzy/Shared/Components/KeyCapView.swift
struct KeyCapView: View {
  let symbol: String
  var fontSize: CGFloat = 12

  var body: some View {
    Text(symbol)
      .font(.system(size: fontSize, weight: .medium, design: .rounded))
      .foregroundColor(.primary)
      .frame(minWidth: 24, minHeight: 22)
      ...
  }
}

struct KeyCapGroupView: View {
  let parts: [String]
  var fontSize: CGFloat = 12
  // inserts a "+" between parts — NOT what we want for the Arc look
}
```

- **The canonical exemplar for the floating window** — mirror this exact
  `NSPanel` setup (borderless, non-activating, click-through, clear background,
  `NSHostingView`, alpha fade). It is a `@MainActor` singleton that owns one
  reusable panel:

```295:331:Snapzy/Services/Diagnostics/AppToastManager.swift
      let newPanel = NSPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )
      newPanel.level = .statusBar
      newPanel.isOpaque = false
      newPanel.backgroundColor = .clear
      newPanel.hasShadow = true
      newPanel.hidesOnDeactivate = false
      newPanel.ignoresMouseEvents = true
      newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
      newPanel.contentView = NSHostingView(rootView: AppToastView(viewModel: viewModel))
      newPanel.alphaValue = 0
      newPanel.orderFrontRegardless()
      panel = newPanel
```

  and its fade in/out:

```316:353:Snapzy/Services/Diagnostics/AppToastManager.swift
    if let panel {
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.16
        panel.animator().alphaValue = 1
      }
    }
    ...
  private func dismissIfNeeded(presentationID: UUID) {
    guard presentationID == activePresentationID else { return }
    guard let panel else { return }

    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.16
      panel.animator().alphaValue = 0
    }, completionHandler: {
      panel.orderOut(nil)
    })
  }
```

- **Repo conventions that apply here**:
  - Presenters/overlays that own an `NSPanel` are `@MainActor final class` singletons with a `static let shared` (see `AppToastManager`, `Snapzy/Services/Diagnostics/AppToastManager.swift:193-203`).
  - Pure geometry is a separate `enum` with `static` functions and its own XCTest, so the math is testable without a UI (see `NotinhasNoteGeometry` and `SnapzyTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`). Match this: the placement math goes in its own enum with a unit test.
  - The Xcode project uses **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup`). New files placed under `Snapzy/` and `SnapzyTests/` are picked up automatically — you do **not** edit `Snapzy.xcodeproj/project.pbxproj`.
- **Screen coordinate note**: AppKit screen coordinates have a bottom-left origin with y increasing upward. A toolbar button sits near the top of its window (high y); a tooltip shown *visually below* it has a *lower* y. The editor footer buttons sit near the bottom; a tooltip shown *visually above* them has a *higher* y. The placement enum encodes this and flips edges when the preferred edge would run off the visible screen.

## Commands you will need

| Purpose      | Command                                                                          | Expected on success            |
|--------------|----------------------------------------------------------------------------------|--------------------------------|
| Format       | `swiftformat Snapzy/Shared/Components/OverlayTooltip SnapzyTests/Shared`          | exit 0                         |
| Build + run  | `./scripts/build_and_run.sh`                                                      | app builds and launches        |
| Tests (all)  | `./scripts/run-tests.sh`                                                          | build + test suite pass        |
| Tests (this) | `./scripts/run-tests.sh -only-testing:SnapzyTests/OverlayTooltipPlacementTests`   | new tests pass                 |

(`swiftformat` is the current formatter per `AGENTS.md`; the old `scripts/format.sh` was removed in commit `32e7567` — do not call it.)

## Suggested executor toolkit

- Read `.agents/skills/macos-app-engineering/SKILL.md` (SwiftUI/AppKit hosting, overlay windows) before writing the presenter.
- Read `.agents/skills/swift-concurrency-expert/SKILL.md` — keep all window/AppKit work on `@MainActor`; only the placement math is `nonisolated`/pure.
- Read `.agents/skills/apple-design/SKILL.md` for the bubble's material/typography feel.

## Scope

**In scope** (create these files; the sync group picks them up automatically):
- `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipContent.swift` (create)
- `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipPlacement.swift` (create)
- `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipBubbleView.swift` (create)
- `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipPresenter.swift` (create)
- `Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift` (create)
- `SnapzyTests/Shared/Components/OverlayTooltipPlacementTests.swift` (create)

**Out of scope** (do NOT touch):
- `Snapzy/Shared/Components/KeyCapView.swift` — reuse as-is.
- `Snapzy/Shared/Components/TooltipView.swift` — the existing `.hint()` popover stays; do not modify or delete it.
- `Snapzy/Services/Diagnostics/AppToastManager.swift` — exemplar only; do not change.
- Any Notinhas call site (`AnnotateToolbarView.swift`, `NotinhasNoteEditorView.swift`) — those are plans 018 and 019. This plan adds **no** call sites; the component is verified by build + unit tests + `#Preview`.
- `Snapzy.xcodeproj/project.pbxproj` — do not edit; files auto-sync.

## Git workflow

- Branch: `advisor/017-overlay-tooltip-component`
- Commit style: Conventional Commits. Suggested:
  `feat(ui): add Arc-like overlay tooltip component with keycaps`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Content model

Create `OverlayTooltipContent.swift`:

```swift
import Foundation

/// Data shown inside an overlay tooltip bubble.
struct OverlayTooltipContent: Equatable {
  /// Primary line, e.g. "Reload this page" or "Note".
  var title: String
  /// Keycap symbols shown as small pills, e.g. ["⌘", "R"]. Empty = text-only.
  var keys: [String] = []
  /// Optional secondary line under the title, e.g. a gesture hint.
  var secondary: String? = nil
}

/// Which side of the anchor the tooltip prefers.
enum OverlayTooltipEdge: Equatable {
  case above
  case below
}
```

**Verify**: file saved; continue (compiled together in Step 6).

### Step 2: Pure placement math (the unit-tested core)

Create `OverlayTooltipPlacement.swift`. All inputs/outputs are in AppKit screen
coordinates (bottom-left origin). This type is pure and has no UI dependency:

```swift
import CoreGraphics

enum OverlayTooltipPlacement {
  /// Gap between the anchor and the tooltip bubble, in points.
  static let gap: CGFloat = 6
  /// Minimum inset kept from the visible screen edges.
  static let screenMargin: CGFloat = 8

  /// Computes the tooltip's screen-space origin frame.
  ///
  /// - Horizontally centers the bubble on the anchor, clamped inside `visibleFrame`.
  /// - Vertically places the bubble on `preferred` edge; flips to the other edge
  ///   if the preferred side would run past `visibleFrame`.
  static func frame(
    anchor: CGRect,
    tooltipSize: CGSize,
    visibleFrame: CGRect,
    preferred: OverlayTooltipEdge
  ) -> CGRect {
    // Horizontal: center on anchor, clamp within [minX+margin, maxX-margin-width]
    let rawX = anchor.midX - tooltipSize.width / 2
    let minX = visibleFrame.minX + screenMargin
    let maxX = visibleFrame.maxX - screenMargin - tooltipSize.width
    let x = maxX >= minX ? min(max(rawX, minX), maxX) : minX

    // Vertical candidates (screen y grows upward):
    //  - below the anchor  → lower y
    //  - above the anchor  → higher y
    let belowY = anchor.minY - gap - tooltipSize.height
    let aboveY = anchor.maxY + gap

    let belowFits = belowY >= visibleFrame.minY + screenMargin
    let aboveFits = aboveY + tooltipSize.height <= visibleFrame.maxY - screenMargin

    let y: CGFloat
    switch preferred {
    case .below:
      y = belowFits || !aboveFits ? belowY : aboveY
    case .above:
      y = aboveFits || !belowFits ? aboveY : belowY
    }

    return CGRect(x: x, y: y, width: tooltipSize.width, height: tooltipSize.height)
  }
}
```

**Verify**: file saved; unit-tested in Step 7.

### Step 3: The bubble view (reuses `KeyCapView`)

Create `OverlayTooltipBubbleView.swift`. Lay out `KeyCapView` pills directly (no
`+` separator) to match Arc:

```swift
import SwiftUI

struct OverlayTooltipBubbleView: View {
  let content: OverlayTooltipContent

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(content.title)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.primary)
        if let secondary = content.secondary, !secondary.isEmpty {
          Text(secondary)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
      }

      if !content.keys.isEmpty {
        HStack(spacing: 4) {
          ForEach(Array(content.keys.enumerated()), id: \.offset) { _, key in
            KeyCapView(symbol: key, fontSize: 11)
          }
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.regularMaterial)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
    )
    .fixedSize()
  }
}

#Preview("Overlay Tooltip") {
  VStack(spacing: 16) {
    OverlayTooltipBubbleView(content: .init(title: "Reload this page", keys: ["⌘", "R"]))
    OverlayTooltipBubbleView(content: .init(title: "Save", keys: ["⌘", "⏎"]))
    OverlayTooltipBubbleView(content: .init(title: "Delete note"))
    OverlayTooltipBubbleView(content: .init(
      title: "Note",
      keys: ["N"],
      secondary: "Click to pin · Drag for area"
    ))
  }
  .padding(40)
}
```

**Verify**: file saved; visual check in Step 8 via Xcode `#Preview`.

### Step 4: The presenter (floating `NSPanel`, mirrors `AppToastManager`)

Create `OverlayTooltipPresenter.swift`. It owns one reusable click-through
panel, measures the bubble's fitting size, positions it with
`OverlayTooltipPlacement`, and fades in/out. An `owner` token prevents a
fast move between two adjacent controls from hiding the newer tooltip:

```swift
import AppKit
import SwiftUI

@MainActor
final class OverlayTooltipPresenter {
  static let shared = OverlayTooltipPresenter()

  private var panel: NSPanel?
  private var hostingView: NSHostingView<OverlayTooltipBubbleView>?
  private var currentOwner: UUID?

  private init() {}

  func show(
    _ content: OverlayTooltipContent,
    anchorScreenFrame: CGRect,
    preferred: OverlayTooltipEdge,
    owner: UUID
  ) {
    currentOwner = owner

    let bubble = OverlayTooltipBubbleView(content: content)
    let host = hostingView ?? NSHostingView(rootView: bubble)
    host.rootView = bubble
    let size = host.fittingSize
    guard size.width > 0, size.height > 0 else { return }

    let screen = NSScreen.screens.first { $0.frame.intersects(anchorScreenFrame) }
      ?? NSScreen.main
    guard let visibleFrame = screen?.visibleFrame else { return }

    let frame = OverlayTooltipPlacement.frame(
      anchor: anchorScreenFrame,
      tooltipSize: size,
      visibleFrame: visibleFrame,
      preferred: preferred
    )

    let panel = panel ?? makePanel()
    panel.contentView = host
    hostingView = host
    self.panel = panel

    if panel.isVisible {
      panel.setFrame(frame, display: true)
    } else {
      panel.setFrame(frame, display: true)
      panel.alphaValue = 0
      panel.orderFrontRegardless()
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.12
        panel.animator().alphaValue = 1
      }
    }
  }

  /// Hides the tooltip only if `owner` is the one currently showing.
  func hide(owner: UUID) {
    guard currentOwner == owner else { return }
    currentOwner = nil
    guard let panel, panel.isVisible else { return }
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = 0.10
      panel.animator().alphaValue = 0
    }, completionHandler: {
      panel.orderOut(nil)
    })
  }

  private func makePanel() -> NSPanel {
    let panel = NSPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.level = .popUpMenu
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    return panel
  }
}
```

Notes:
- `level = .popUpMenu` keeps the tooltip above the Annotate window and the note
  editor overlay.
- `ignoresMouseEvents = true` means the panel never steals hover, so the mouse
  stays "over" the anchor control and `.onHover(false)` fires normally on exit.

**Verify**: file saved; compiled in Step 6.

### Step 5: The hover modifier + anchor reader + public API

Create `OverlayTooltipModifier.swift`. It reads the anchor view's screen frame
via a tiny `NSViewRepresentable`, applies a hover-in delay, and drives the
presenter:

```swift
import AppKit
import SwiftUI

extension View {
  /// Shows an Arc-like overlay tooltip on hover.
  func overlayTooltip(
    _ title: String,
    keys: [String] = [],
    secondary: String? = nil,
    edge: OverlayTooltipEdge = .below,
    delay: TimeInterval = 0.35
  ) -> some View {
    modifier(OverlayTooltipModifier(
      content: OverlayTooltipContent(title: title, keys: keys, secondary: secondary),
      edge: edge,
      delay: delay
    ))
  }
}

private final class OverlayTooltipAnchorProxy: ObservableObject {
  weak var view: NSView?

  func screenFrame() -> CGRect? {
    guard let view, let window = view.window else { return nil }
    let inWindow = view.convert(view.bounds, to: nil)
    return window.convertToScreen(inWindow)
  }
}

private struct OverlayTooltipAnchorReader: NSViewRepresentable {
  let proxy: OverlayTooltipAnchorProxy

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async { [weak view] in proxy.view = view }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    proxy.view = nsView
  }
}

private struct OverlayTooltipModifier: ViewModifier {
  let content: OverlayTooltipContent
  let edge: OverlayTooltipEdge
  let delay: TimeInterval

  @StateObject private var proxy = OverlayTooltipAnchorProxy()
  @State private var owner = UUID()
  @State private var showWorkItem: DispatchWorkItem?

  func body(content viewContent: Content) -> some View {
    viewContent
      .background(OverlayTooltipAnchorReader(proxy: proxy))
      .onHover { hovering in
        if hovering {
          scheduleShow()
        } else {
          cancelAndHide()
        }
      }
      .onDisappear { cancelAndHide() }
  }

  private func scheduleShow() {
    showWorkItem?.cancel()
    let work = DispatchWorkItem {
      guard let frame = proxy.screenFrame() else { return }
      OverlayTooltipPresenter.shared.show(
        content,
        anchorScreenFrame: frame,
        preferred: edge,
        owner: owner
      )
    }
    showWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  private func cancelAndHide() {
    showWorkItem?.cancel()
    showWorkItem = nil
    OverlayTooltipPresenter.shared.hide(owner: owner)
  }
}
```

**Verify**: `./scripts/build_and_run.sh` → compiles and launches (Step 6).

### Step 6: Build

Run `./scripts/build_and_run.sh`.

**Verify**: build succeeds and the app launches. No call sites yet, so nothing
new is visible — that is expected.

### Step 7: Unit tests for placement

Create `SnapzyTests/Shared/Components/OverlayTooltipPlacementTests.swift`,
modeled structurally on `SnapzyTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`:

```swift
import CoreGraphics
@testable import Snapzy
import XCTest

final class OverlayTooltipPlacementTests: XCTestCase {
  private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
  private let size = CGSize(width: 120, height: 40)

  func testBelowPlacesTooltipUnderAnchorWhenItFits() {
    let anchor = CGRect(x: 400, y: 700, width: 40, height: 28) // near top
    let frame = OverlayTooltipPlacement.frame(
      anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below
    )
    // "below" = lower y = anchor.minY - gap - height
    XCTAssertEqual(frame.origin.y, 700 - OverlayTooltipPlacement.gap - 40, accuracy: 0.001)
    // horizontally centered on the anchor
    XCTAssertEqual(frame.midX, anchor.midX, accuracy: 0.001)
  }

  func testBelowFlipsToAboveWhenNoRoomUnderAnchor() {
    let anchor = CGRect(x: 400, y: 10, width: 40, height: 28) // near bottom
    let frame = OverlayTooltipPlacement.frame(
      anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below
    )
    // flipped: "above" = anchor.maxY + gap
    XCTAssertEqual(frame.origin.y, anchor.maxY + OverlayTooltipPlacement.gap, accuracy: 0.001)
  }

  func testAbovePlacesTooltipOverAnchorWhenItFits() {
    let anchor = CGRect(x: 400, y: 100, width: 40, height: 28)
    let frame = OverlayTooltipPlacement.frame(
      anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .above
    )
    XCTAssertEqual(frame.origin.y, anchor.maxY + OverlayTooltipPlacement.gap, accuracy: 0.001)
  }

  func testHorizontalClampKeepsTooltipOnScreen() {
    let anchor = CGRect(x: 980, y: 400, width: 20, height: 20) // far right
    let frame = OverlayTooltipPlacement.frame(
      anchor: anchor, tooltipSize: size, visibleFrame: screen, preferred: .below
    )
    XCTAssertLessThanOrEqual(
      frame.maxX,
      screen.maxX - OverlayTooltipPlacement.screenMargin + 0.001
    )
    XCTAssertGreaterThanOrEqual(
      frame.minX,
      screen.minX + OverlayTooltipPlacement.screenMargin - 0.001
    )
  }
}
```

**Verify**: `./scripts/run-tests.sh -only-testing:SnapzyTests/OverlayTooltipPlacementTests` → all 4 tests pass.

### Step 8: Visual sanity + format

- Open `OverlayTooltipBubbleView.swift` in Xcode and run the `#Preview`; confirm
  the four bubbles render (text-only, text+keys, and text+keys+secondary).
- Run `swiftformat Snapzy/Shared/Components/OverlayTooltip SnapzyTests/Shared`.

**Verify**: `swiftformat ...` exits 0; preview renders.

## Test plan

- **New unit tests** in `SnapzyTests/Shared/Components/OverlayTooltipPlacementTests.swift`:
  happy path below-fits, flip-to-above when no room, above-fits, horizontal clamp
  at the screen edge. Model after `NotinhasNoteGeometryTests` (same `@testable
  import Snapzy` + `XCTest` structure).
- **No UI/snapshot test** for the presenter or hover lifecycle — the repo has no
  harness for `NSPanel` overlays; do not add a flaky one. The placement math
  (the only logic worth testing) is covered by the unit tests above; the
  presenter/hover wiring is validated visually in plans 018/019.
- Verification: `./scripts/run-tests.sh` → full suite passes, including the 4 new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] `./scripts/run-tests.sh` passes (full suite, no regressions)
- [ ] `./scripts/run-tests.sh -only-testing:SnapzyTests/OverlayTooltipPlacementTests` → 4 tests pass
- [ ] `rg -l "OverlayTooltip" Snapzy/Shared/Components/OverlayTooltip` lists all 5 new component files
- [ ] `rg -n "func overlayTooltip" Snapzy/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift` returns the public API
- [ ] `git status` shows only the 6 new files (5 under `Snapzy/Shared/Components/OverlayTooltip/`, 1 under `SnapzyTests/Shared/Components/`) plus `plans/README.md` — no other files, and `Snapzy.xcodeproj/project.pbxproj` is unchanged
- [ ] `swiftformat Snapzy/Shared/Components/OverlayTooltip SnapzyTests/Shared` exits 0
- [ ] `plans/README.md` status row for 017 updated

## STOP conditions

Stop and report back (do not improvise) if:

- The `KeyCapView` initializer differs from the "Current state" excerpt (a
  `symbol:`/`fontSize:` signature change means the bubble code must adapt).
- The new test file does **not** get compiled into the test target (running the
  filtered test reports "no tests"), i.e. the file-system-synchronized group is
  not picking it up — report before hand-editing `project.pbxproj`.
- `NSHostingView.fittingSize` returns `.zero` at show time so the tooltip never
  appears — report before adding manual size hacks.
- `window.convertToScreen(_:)` returns visibly wrong coordinates (tooltip lands
  on the wrong monitor / far from the anchor) — report before rewriting the
  coordinate path.
- A verification command fails twice after a reasonable fix attempt.

## Maintenance notes

- This component is intentionally general (title + keys + optional secondary) but
  is only *adopted* in the Notinhas flow by plans 018/019. Do not sweep it across
  every `.help(...)` in the app without a separate, explicit decision.
- Only one tooltip shows at a time (single shared panel + `owner` token). If a
  future need arises for simultaneous tooltips, the presenter must grow to a
  panel pool — revisit `hide(owner:)`/`show(...)` then.
- The existing `.hint()` popover (`TooltipView.swift`) still exists for plain
  text hints elsewhere; a reviewer should confirm this plan did not touch or
  duplicate it.
- If the app later supports Reduce Motion, gate the alpha fades on
  `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
