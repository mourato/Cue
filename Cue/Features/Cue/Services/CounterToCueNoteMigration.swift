//
//  CounterToCueNoteMigration.swift
//  Notinhas
//
//  One-shot migration of legacy Counter annotations into empty Notinhas notes.
//

import CoreGraphics
import Foundation

enum CounterToCueNoteMigration {
    struct Result: Equatable {
        var annotations: [AnnotationItem]
        var cueNotes: [CueVisualNote]
        var didMigrate: Bool
    }

    /// Converts legacy counter annotations into empty Notinhas notes appended after
    /// `cueNotes`, then removes counters from `annotations`. Idempotent when no
    /// counters remain.
    static func migrate(
        annotations: [AnnotationItem],
        cueNotes: [CueVisualNote],
    ) -> Result {
        let hasCounters = annotations.contains { item in
            if case .counter = item.type {
                return true
            }
            return false
        }
        guard hasCounters else {
            return Result(annotations: annotations, cueNotes: cueNotes, didMigrate: false)
        }

        var notes = cueNotes
        var nextCreationOrder = CueNoteGeometry.nextCreationOrder(in: notes)
        var migratedNotes: [CueVisualNote] = []

        for item in annotations {
            guard case .counter = item.type else { continue }
            let center = CGPoint(x: item.bounds.midX, y: item.bounds.midY)
            let rgba = RGBAColor(color: item.properties.strokeColor)
                ?? RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
            let note = CueVisualNote(
                target: .point(center),
                color: rgba,
                pinControlValue: AnnotationProperties.clampedControlValue(item.properties.strokeWidth),
                creationOrder: nextCreationOrder,
            )
            migratedNotes.append(note)
            nextCreationOrder += 1
        }

        notes.append(contentsOf: migratedNotes)

        let strippedAnnotations = annotations.filter { item in
            if case .counter = item.type {
                return false
            }
            return true
        }

        return Result(
            annotations: strippedAnnotations,
            cueNotes: notes,
            didMigrate: true,
        )
    }
}

extension AnnotateState {
    /// Migrates legacy Counter annotations into empty Notinhas notes on session open.
    func migrateLegacyCountersToNotinhasIfNeeded() {
        let result = CounterToCueNoteMigration.migrate(
            annotations: annotations,
            cueNotes: cueNotes,
        )
        guard result.didMigrate else { return }
        annotations = result.annotations
        cueNotes = result.cueNotes
        hasUnsavedChanges = true
    }
}
