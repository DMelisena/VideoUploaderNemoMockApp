import AVFoundation
import Foundation
import UniformTypeIdentifiers

protocol VideoProcessingServiceProtocol {
    func processVideo(from url: URL) async throws -> URL
}

class VideoProcessingService: VideoProcessingServiceProtocol {
    func processVideo(from url: URL) async throws -> URL {
        // First, ensure we have a valid file at the URL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VideoProcessingError.fileNotFound(url.path)
        }

        // Create a permanent copy of the file in temp directory
        let permanentURL = try createPermanentCopy(from: url)

        let videoFileExtension = permanentURL.pathExtension.lowercased()

        if videoFileExtension == "mp4" {
            return permanentURL
        } else {
            return try await convertToMP4(from: permanentURL)
        }
    }

    private func createPermanentCopy(from url: URL) throws -> URL {
        let originalFileName = url.lastPathComponent
        let fileExtension = url.pathExtension
        let fileNameWithoutExtension = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let uniqueFileName = "\(fileNameWithoutExtension)_\(UUID().uuidString).\(fileExtension)"
        let permanentURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: permanentURL.path) {
            try FileManager.default.removeItem(at: permanentURL)
        }

        // Copy the file to a permanent location
        try FileManager.default.copyItem(at: url, to: permanentURL)

        // Verify the copy was successful
        guard FileManager.default.fileExists(atPath: permanentURL.path) else {
            throw VideoProcessingError.copyFailed
        }

        return permanentURL
    }

    private func convertToMP4(from videoURL: URL) async throws -> URL {
        let avAsset = AVURLAsset(url: videoURL, options: nil)

        // Check if the asset is readable
        guard avAsset.isReadable else {
            throw VideoProcessingError.assetNotReadable
        }

        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "converted_\(UUID().uuidString).mp4"
        let outputURL = tempDirectory.appendingPathComponent(fileName)

        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true

        let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 600)
        let range = CMTimeRangeMake(start: start, duration: avAsset.duration)
        exportSession.timeRange = range

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    // Clean up original file after successful conversion
                    try? FileManager.default.removeItem(at: videoURL)
                    continuation.resume(returning: outputURL)
                case .failed:
                    let error = exportSession.error ?? VideoProcessingError.conversionFailed
                    print("Export failed with error: \(error)")
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: VideoProcessingError.conversionCancelled)
                default:
                    break
                }
            }
        }
    }
}

enum VideoProcessingError: Error, LocalizedError {
    case fileNotFound(String)
    case copyFailed
    case assetNotReadable
    case exportSessionCreationFailed
    case conversionFailed
    case conversionCancelled

    var errorDescription: String? {
        switch self {
        case let .fileNotFound(path):
            return "Video file not found at path: \(path)"
        case .copyFailed:
            return "Failed to create a permanent copy of the video file"
        case .assetNotReadable:
            return "Video asset is not readable"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .conversionFailed:
            return "Video conversion failed"
        case .conversionCancelled:
            return "Video conversion was cancelled"
        }
    }
}
