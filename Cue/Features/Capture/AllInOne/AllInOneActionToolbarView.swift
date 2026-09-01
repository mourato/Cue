//
//  AllInOneActionToolbarView.swift
//  Notinhas
//
//  Dimensions and aspect lock controls for All-In-One.
//

import SwiftUI

struct AllInOneActionToolbarView: View {
    @ObservedObject var session: AllInOneCaptureSessionState

    var body: some View {
        if session.selectedMode.showsDimensionsBar, let rect = session.currentRect {
            AllInOneDimensionsBarView(rect: rect) { updated in
                session.updateRect(updated)
            }
        }
    }
}

#Preview {
    let session = AllInOneCaptureSessionState()
    session.currentRect = CGRect(x: 100, y: 200, width: 640, height: 360)
    return AllInOneActionToolbarView(session: session)
        .padding()
}
