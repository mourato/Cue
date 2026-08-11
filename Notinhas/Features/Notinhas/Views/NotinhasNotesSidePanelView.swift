import SwiftUI

struct NotinhasNotesSidePanelView: View {
    let notes: [NotinhasVisualNote]
    let selectedNoteID: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NotinhasL10n.sidePanelTitle)
                .font(.system(size: 13, weight: .semibold))

            if notes.isEmpty {
                Text(NotinhasL10n.sidePanelEmpty)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        sidePanelRow(note: note, displayNumber: index + 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sidePanelRow(note: NotinhasVisualNote, displayNumber: Int) -> some View {
        let isSelected = note.id == selectedNoteID
        HStack(alignment: .top, spacing: 8) {
            Button {
                onSelect(note.id)
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text("\(displayNumber)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.accentColor))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text.isEmpty ? NotinhasL10n.emptyNoteLabel : note.text)
                            .font(.system(size: 12))
                            .foregroundStyle(note.text.isEmpty ? .secondary : .primary)
                            .lineLimit(3)

                        Text(note.target.kindLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                L10n.Notinhas.noteRowLabel(
                    number: displayNumber,
                    text: note.text.isEmpty ? NotinhasL10n.emptyNoteLabel : note.text,
                    target: note.target.kindLabel,
                ),
            )
            .accessibilityValue(isSelected ? NotinhasL10n.selected : "")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button(role: .destructive) {
                onDelete(note.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(NotinhasL10n.deleteNote)
            .accessibilityLabel(NotinhasL10n.deleteNote)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear),
        )
    }
}

private extension NotinhasNoteTarget {
    var kindLabel: String {
        switch self {
        case .point:
            NotinhasL10n.pointTargetLabel
        case .rect:
            NotinhasL10n.rectTargetLabel
        }
    }
}
