import AVKit
import SwiftUI

struct PiPPlayerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.updatesNowPlayingInfoCenter = true
        controller.player = AVPlayer(url: url)
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        let currentAsset = controller.player?.currentItem?.asset as? AVURLAsset
        guard currentAsset?.url != url else { return }

        controller.player = AVPlayer(url: url)
        controller.player?.play()
    }
}
