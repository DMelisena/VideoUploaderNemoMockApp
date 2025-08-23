//
//  VideoPicker.swift
//  videoUploaderApp
//
//  Created by Arya Hanif on 23/08/25.
//
import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private var parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else { return }
            
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let url = url {
                    // Create unique temporary URL for the original file
                    let originalFileName = url.lastPathComponent
                    let fileExtension = url.pathExtension
                    let fileNameWithoutExtension = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
                    let uniqueFileName = "\(fileNameWithoutExtension)_\(UUID().uuidString).\(fileExtension)"
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)
                    
                    do {
                        // Remove existing file if it exists
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }
                        
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        
                        // Check if video needs conversion to MP4
                        let videoFileExtension = tempURL.pathExtension.lowercased()
                        
                        if videoFileExtension == "mp4" {
                            // Already MP4, use directly
                            DispatchQueue.main.async {
                                self.parent.videoURL = tempURL
                            }
                        } else {
                            // Convert to MP4
                            self.encodeVideoToMP4(at: tempURL) { convertedURL, error in
                                DispatchQueue.main.async {
                                    if let convertedURL = convertedURL {
                                        self.parent.videoURL = convertedURL
                                    } else {
                                        // If conversion fails, use original file
                                        print("Video conversion failed: \(error?.localizedDescription ?? "Unknown error")")
                                        self.parent.videoURL = tempURL
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Error handling file: \(error)")
                        // Fallback: try to use the original URL directly
                        DispatchQueue.main.async {
                            self.parent.videoURL = url
                        }
                    }
                }
            }
        }
        
        private func encodeVideoToMP4(at videoURL: URL, completionHandler: ((URL?, Error?) -> Void)?) {
            let avAsset = AVURLAsset(url: videoURL, options: nil)
            let startDate = Date()
            
            // Create Export session
            guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
                completionHandler?(nil, NSError(domain: "VideoConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
                return
            }
            
            // Creating temp path to save the converted video
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "converted_\(UUID().uuidString).mp4"
            let filePath = tempDirectory.appendingPathComponent(fileName)
            
            // Check if the file already exists then remove the previous file
            if FileManager.default.fileExists(atPath: filePath.path) {
                do {
                    try FileManager.default.removeItem(at: filePath)
                } catch {
                    completionHandler?(nil, error)
                    return
                }
            }
            
            exportSession.outputURL = filePath
            exportSession.outputFileType = AVFileType.mp4
            exportSession.shouldOptimizeForNetworkUse = true
            
            let start = CMTimeMakeWithSeconds(0.0, preferredTimescale: 600)
            let range = CMTimeRangeMake(start: start, duration: avAsset.duration)
            exportSession.timeRange = range
            
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .failed:
                    print("Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
                    completionHandler?(nil, exportSession.error)
                case .cancelled:
                    print("Export canceled")
                    completionHandler?(nil, NSError(domain: "VideoConversion", code: -2, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"]))
                case .completed:
                    let endDate = Date()
                    let time = endDate.timeIntervalSince(startDate)
                    print("Video conversion completed in \(time) seconds")
                    print("Output URL: \(exportSession.outputURL?.absoluteString ?? "NO OUTPUT URL")")
                    
                    // Clean up original file if conversion was successful
                    try? FileManager.default.removeItem(at: videoURL)
                    
                    completionHandler?(exportSession.outputURL, nil)
                default:
                    break
                }
            }
        }
    }
}
