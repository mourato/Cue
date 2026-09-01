//
//  HistoryFormatterCache.swift
//  Notinhas
//
//  Centralized, thread-safe formatter cache for History views and records
//

import Foundation

enum HistoryFormatterCache {
    static func relativeFull() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    static func relativeShort() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }

    static func recordDate() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static func fileSize() -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }
}
