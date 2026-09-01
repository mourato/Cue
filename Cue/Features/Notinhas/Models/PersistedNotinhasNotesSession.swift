//
//  PersistedNotinhasNotesSession.swift
//  Notinhas
//
//  Optional Notinhas payload stored alongside annotation sidecars.
//

import Foundation

nonisolated struct PersistedNotinhasNotesSession: Codable, Equatable {
    var notes: [NotinhasVisualNote]

    init(notes: [NotinhasVisualNote] = []) {
        self.notes = notes
    }
}
