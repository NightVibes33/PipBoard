import CoreMedia
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // ReplayKit starts only after the user explicitly approves screen broadcast.
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {}

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            break
        case .audioApp, .audioMic:
            break
        @unknown default:
            break
        }
    }
}
