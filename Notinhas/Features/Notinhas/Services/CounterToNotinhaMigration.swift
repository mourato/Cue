//
//  CounterToNotinhaMigration.swift
//  Notinhas
//
//  One-shot migration of legacy Counter annotations into empty Notinhas notes.
//

import CoreGraphics
import Foundation

enum CounterToNotinhaMigration {
    struct Result: Equatable {
        var annotations: [AnnotationItem]
        var notinhasNotes: [NotinhasVisualNote]
        var didMigrate: Bool
    }

    /// Converts legacy counter annotations into empty Notinhas notes appended after
    /// `notinhasNotes`, then removes counters from `annotations`. Idempotent when no
    /// counters remain.
    static func migrate(
        annotations: [AnnotationItem],
        notinhasNotes: [NotinhasVisualNote],
    ) -> Result {
        let hasCounters = annotations.contains { item in
            if case .counter = item.type {
                return true
            }
            return false
        }
        guard hasCounters else {
            return Result(annotations: annotations, notinhasNotes: notinhasNotes, didMigrate: false)
        }

        var notes = notinhasNotes
        var nextCreationOrder = NotinhasNoteGeometry.nextCreationOrder(in: notes)
        var migratedNotes: [NotinhasVisualNote] = []

        for item in annotations {
            guard case .counter = item.type else { continue }
            let center = CGPoint(x: item.bounds.midX, y: item.bounds.midY)
            let rgba = RGBAColor(color: item.properties.strokeColor)
                ?? RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
            let note = NotinhasVisualNote(
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
            notinhasNotes: notes,
            didMigrate: true,
        )
    }
}

extension AnnotateState {
    /// Migrates legacy Counter annotations into empty Notinhas notes on session open.
    func migrateLegacyCountersToNotinhasIfNeeded() {
        let result = CounterToNotinhaMigration.migrate(
            annotations: annotations,
            notinhasNotes: notinhasNotes,
        )
        guard result.didMigrate else { return }
        annotations = result.annotations
        notinhasNotes = result.notinhasNotes
        hasUnsavedChanges = true
    }
}
