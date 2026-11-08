// Optional H.264 delivery encode, preserving frame size and playback timing.
// Usage: swift CompressVideo.swift input.mp4 output.mp4
import Foundation
import AVFoundation
import CoreVideo
let args = CommandLine.arguments
guard args.count == 3 else { fatalError("Usage: CompressVideo.swift input.mp4 output.mp4") }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let track = asset.tracks(withMediaType: .video).first!
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
output.alwaysCopiesSampleData = false
reader.add(output)
let url = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: url)
let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: Int(track.naturalSize.width),
    AVVideoHeightKey: Int(track.naturalSize.height),
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 2_200_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoMaxKeyFrameIntervalKey: 60,
        AVVideoExpectedSourceFrameRateKey: 30
    ]
])
input.expectsMediaDataInRealTime = false
writer.add(input)
guard writer.startWriting(), reader.startReading() else { fatalError("Could not begin encode") }
writer.startSession(atSourceTime: .zero)
while let sample = output.copyNextSampleBuffer() {
    while !input.isReadyForMoreMediaData {
        guard writer.status == .writing else { fatalError("Writer failed: \(String(describing: writer.error))") }
        RunLoop.current.run(until: Date().addingTimeInterval(0.01))
    }
    guard input.append(sample) else { fatalError("Append failed: \(String(describing: writer.error))") }
}
guard reader.status == .completed else { fatalError("Decode failed: \(String(describing: reader.error))") }
input.markAsFinished()
writer.finishWriting {}
while writer.status == .writing { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
guard writer.status == .completed else { fatalError("Encode failed: \(String(describing: writer.error))") }
print("Saved H.264 delivery file: \(url.path)")
