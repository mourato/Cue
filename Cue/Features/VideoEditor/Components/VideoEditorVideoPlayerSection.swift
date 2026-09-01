#if CUE_VIDEO_MODULE
//
    //  VideoPlayerSection.swift
    //  Notinhas
//
    //  NSViewRepresentable wrapper for AVPlayerView
//

    import AVKit
    import SwiftUI

    /// SwiftUI wrapper for AVPlayerView with custom controls disabled
    struct VideoPlayerSection: NSViewRepresentable {
        let player: AVPlayer
        var videoGravity: AVLayerVideoGravity = .resizeAspect

        func makeNSView(context _: Context) -> AVPlayerView {
            let view = AVPlayerView()
            view.player = player
            view.controlsStyle = .none
            view.showsFullScreenToggleButton = false
            view.videoGravity = videoGravity
            return view
        }

        func updateNSView(_ view: AVPlayerView, context _: Context) {
            view.videoGravity = videoGravity
            // Player is managed by state, no updates needed.
        }
    }
#endif
