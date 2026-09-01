//
//  PersistedCueNotesSession.swift
//  Notinhas
//
//  Optional Notinhas payload stored alongside annotation sidecars.
//

import Foundation

nonisolated struct PersistedCueNotesSession: Codable, Equatable {
    var notes: [CueVisualNote]

    init(notes: [CueVisualNote] = []) {
        self.notes = notes
    }
}
