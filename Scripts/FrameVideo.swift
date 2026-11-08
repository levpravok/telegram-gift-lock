// macOS command-line compositor: frames an actual app screen recording.
// Usage: swift FrameVideo.swift input.mov output.mp4 [startSeconds] [duration]
import Foundation
import AVFoundation
import AppKit
import QuartzCore

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("Usage: FrameVideo.swift input.mov output.mp4 [startSeconds] [duration]") }
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])
let start = args.count > 3 ? Double(args[3])! : 0.5
let requestedDuration = args.count > 4 ? Double(args[4])! : 28.0
let source = AVURLAsset(url: input)
guard let sourceTrack = source.tracks(withMediaType: .video).first else { fatalError("No video track") }
let duration = min(requestedDuration, source.duration.seconds - start)
guard duration > 0 && duration <= 30 else { fatalError("Submission duration must be within 30 seconds") }
let composition = AVMutableComposition()
let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try track.insertTimeRange(CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), duration: CMTime(seconds: duration, preferredTimescale: 600)), of: sourceTrack, at: .zero)
let size = CGSize(width: 1080, height: 1080)
let sourceSize = sourceTrack.naturalSize
let scale = 970.0 / sourceSize.height
let screen = CGRect(x: (1080 - sourceSize.width * scale) / 2, y: 55, width: sourceSize.width * scale, height: 970)
let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
layerInstruction.setTransform(sourceTrack.preferredTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale)).concatenating(CGAffineTransform(translationX: screen.minX, y: screen.minY)), at: .zero)
instruction.layerInstructions = [layerInstruction]
let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = size
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = [instruction]

let parent = CALayer()
parent.frame = CGRect(origin: .zero, size: size)
let background = CAGradientLayer()
background.frame = parent.bounds
background.colors = [NSColor(red: 0.46, green: 0.76, blue: 0.70, alpha: 1).cgColor, NSColor(red: 0.42, green: 0.47, blue: 0.88, alpha: 1).cgColor]
background.startPoint = CGPoint(x: 0, y: 1)
background.endPoint = CGPoint(x: 1, y: 0)
parent.addSublayer(background)
let body = CALayer()
body.frame = screen.insetBy(dx: -9, dy: -9)
body.cornerRadius = 56
body.backgroundColor = NSColor(white: 0.07, alpha: 1).cgColor
body.borderWidth = 3
body.borderColor = NSColor(white: 0.65, alpha: 1).cgColor
body.shadowColor = NSColor.black.cgColor
body.shadowOpacity = 0.30
body.shadowOffset = CGSize(width: 0, height: -12)
body.shadowRadius = 17
parent.addSublayer(body)
let videoLayer = CALayer()
videoLayer.frame = parent.bounds
let mask = CAShapeLayer()
mask.path = CGPath(roundedRect: screen, cornerWidth: 46, cornerHeight: 46, transform: nil)
videoLayer.mask = mask
parent.addSublayer(videoLayer)
let caption = CATextLayer()
caption.string = "Gift Lock · Working iOS prototype"
caption.font = NSFont.systemFont(ofSize: 16, weight: .medium)
caption.fontSize = 16
caption.foregroundColor = NSColor.white.withAlphaComponent(0.92).cgColor
caption.alignmentMode = .center
caption.frame = CGRect(x: 0, y: 12, width: 1080, height: 25)
caption.contentsScale = 2
parent.addSublayer(caption)
videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)
try? FileManager.default.removeItem(at: output)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1920x1080) else { fatalError("No exporter") }
exporter.outputURL = output
exporter.outputFileType = .mp4
exporter.videoComposition = videoComposition
exporter.shouldOptimizeForNetworkUse = true
exporter.exportAsynchronously {}
while exporter.status == .waiting || exporter.status == .exporting || exporter.status == .unknown {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
guard exporter.status == .completed else { fatalError("Export failed: \(String(describing: exporter.error))") }
print("Exported \(duration)s, 1080 × 1080, MP4: \(output.path)")
