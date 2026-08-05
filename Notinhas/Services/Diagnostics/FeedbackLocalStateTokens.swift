//
//  FeedbackLocalStateTokens.swift
//  Notinhas
//
//  Semantic tokens for immediate local control feedback (not global toasts).
//

import SwiftUI

enum FeedbackQuickAccessButtonState: Equatable {
    case disabled
    case `default`
    case hover
    case pressed
}

enum FeedbackUploadHistoryActionState: Equatable {
    case `default`
    case copiedSuccess
    case destructive
}

enum FeedbackLocalStateTokens {
    static func quickAccessButtonBackground(for state: FeedbackQuickAccessButtonState) -> Color {
        switch state {
        case .disabled:
            Color.black.opacity(0.4)
        case .default:
            Color.black.opacity(0.6)
        case .hover:
            Color.white.opacity(0.35)
        case .pressed:
            Color.white.opacity(0.5)
        }
    }

    static func quickAccessButtonForegroundOpacity(isEnabled: Bool) -> Double {
        isEnabled ? 1 : 0.7
    }

    static func uploadHistoryActionIconColor(for state: FeedbackUploadHistoryActionState) -> Color {
        switch state {
        case .default:
            .white
        case .copiedSuccess:
            FeedbackStyle(tone: .success).iconColor
        case .destructive:
            FeedbackStyle(tone: .error).iconColor
        }
    }
}
