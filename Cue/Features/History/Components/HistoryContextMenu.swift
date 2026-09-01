//
//  HistoryContextMenu.swift
//  Notinhas
//
//  Context menu for history items
//

import SwiftUI

struct HistoryContextMenu: View {
    let record: CaptureHistoryRecord

    var body: some View {
        Button("Open in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([record.fileURL])
        }

        Button("Copy") {
            HistoryWindowController.shared.copyToClipboard([record])
        }

        Button("Edit") {
            HistoryWindowController.shared.openItem(record)
        }

        Divider()

        Button("Delete") {
            HistoryWindowController.shared.deleteRecords([record], asksConfirmation: false)
        }
    }
}
