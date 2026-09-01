//
//  AllInOneDimensionsBarView.swift
//  Notinhas
//
//  Compact width × height fields and aspect-ratio lock for All-In-One selection refinement.
//

import SwiftUI

struct AllInOneDimensionsBarView: View {
    private static let modeButtonContentHeight: CGFloat = 46

    let rect: CGRect
    let onRectChanged: (CGRect) -> Void

    @AppStorage(PreferencesKeys.captureAllInOneAspectRatioLocked) private var aspectRatioLocked = false
    @State private var widthText: String
    @State private var heightText: String
    @State private var lockedAspectRatio: CGFloat?

    init(rect: CGRect, onRectChanged: @escaping (CGRect) -> Void) {
        self.rect = rect
        self.onRectChanged = onRectChanged
        _widthText = State(initialValue: Self.formattedDimension(rect.width))
        _heightText = State(initialValue: Self.formattedDimension(rect.height))
        _lockedAspectRatio = State(initialValue: CaptureSelectionGeometry.aspectRatio(of: rect))
    }

    var body: some View {
        HStack(spacing: ToolbarConstants.itemSpacing) {
            dimensionFieldGroup

            CaptureFloatingToolbarDivider()

            CaptureFloatingToolbarIconButton(
                systemName: aspectRatioLocked ? "lock.fill" : "lock.open",
                action: toggleAspectLock,
                accessibilityLabel: aspectRatioLocked
                    ? L10n.AllInOne.unlockAspectRatioAccessibility
                    : L10n.AllInOne.lockAspectRatioAccessibility,
            )
        }
        // Match mode-strip button content height before shared padding (outer ≈ 58).
        .frame(minHeight: Self.modeButtonContentHeight)
        .padding(.horizontal, ToolbarConstants.horizontalPadding)
        .padding(.vertical, ToolbarConstants.verticalPadding)
        .captureFloatingToolbarMaterial()
        .onChange(of: rect) { newRect in
            syncFields(from: newRect)
        }
    }

    // MARK: - Private

    private var dimensionFieldGroup: some View {
        HStack(spacing: 6) {
            dimensionField(
                accessibilityLabel: L10n.AllInOne.widthFieldAccessibility,
                text: $widthText,
            ) {
                commitWidth()
            }

            Text("×")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            dimensionField(
                accessibilityLabel: L10n.AllInOne.heightFieldAccessibility,
                text: $heightText,
            ) {
                commitHeight()
            }
        }
    }

    private func dimensionField(
        accessibilityLabel: String,
        text: Binding<String>,
        onCommit: @escaping () -> Void,
    ) -> some View {
        TextField("", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .frame(width: 48)
            .multilineTextAlignment(.trailing)
            .accessibilityLabel(accessibilityLabel)
            .onSubmit(onCommit)
    }

    private func commitWidth() {
        guard let width = parsedDimension(widthText) else {
            syncFields(from: rect)
            return
        }

        let updated = CaptureSelectionGeometry.rectBySettingWidth(
            rect,
            width: width,
            aspectLocked: aspectRatioLocked,
            aspectRatio: activeAspectRatio(),
        )
        if aspectRatioLocked {
            lockedAspectRatio = CaptureSelectionGeometry.aspectRatio(of: updated)
        }
        onRectChanged(updated)
        syncFields(from: updated)
    }

    private func commitHeight() {
        guard let height = parsedDimension(heightText) else {
            syncFields(from: rect)
            return
        }

        let updated = CaptureSelectionGeometry.rectBySettingHeight(
            rect,
            height: height,
            aspectLocked: aspectRatioLocked,
            aspectRatio: activeAspectRatio(),
        )
        if aspectRatioLocked {
            lockedAspectRatio = CaptureSelectionGeometry.aspectRatio(of: updated)
        }
        onRectChanged(updated)
        syncFields(from: updated)
    }

    private func toggleAspectLock() {
        aspectRatioLocked.toggle()
        if aspectRatioLocked {
            lockedAspectRatio = CaptureSelectionGeometry.aspectRatio(of: rect) ?? activeAspectRatio()
            guard let ratio = lockedAspectRatio else { return }
            let updated = CaptureSelectionGeometry.rectByLockingAspectRatio(rect, aspectRatio: ratio)
            onRectChanged(updated)
            syncFields(from: updated)
        }
    }

    private func activeAspectRatio() -> CGFloat? {
        if let lockedAspectRatio, aspectRatioLocked {
            return lockedAspectRatio
        }
        return CaptureSelectionGeometry.aspectRatio(of: rect)
    }

    private func syncFields(from rect: CGRect) {
        widthText = Self.formattedDimension(rect.width)
        heightText = Self.formattedDimension(rect.height)
    }

    private func parsedDimension(_ text: String) -> CGFloat? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else { return nil }
        return CGFloat(value)
    }

    private static func formattedDimension(_ value: CGFloat) -> String {
        String(max(1, Int(value.rounded())))
    }
}

#Preview {
    AllInOneDimensionsBarView(rect: CGRect(x: 0, y: 0, width: 640, height: 360)) { _ in }
        .padding()
}
