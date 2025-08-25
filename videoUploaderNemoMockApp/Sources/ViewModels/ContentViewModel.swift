import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var videoURL: URL?
    @Published var uploadStatus = ""
    @Published var downloadURL = ""
    @Published var helloWorldMessage = "Tap the button to fetch data."
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var folders: [FolderItem] = []
    @Published var showGallery = false
    @Published var debugInfo = ""
    @Published var showDownloadedFiles = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0

    // MARK: - Dependencies

    private let networkService: NetworkServiceProtocol
    private let fileService: FileServiceProtocol
    private let videoProcessingService: VideoProcessingServiceProtocol

    // MARK: - Private Properties

    private var downloadTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?

    init(
        networkService: NetworkServiceProtocol = NetworkService(),
        fileService: FileServiceProtocol = FileService(),
        videoProcessingService: VideoProcessingServiceProtocol = VideoProcessingService()
    ) {
        self.networkService = networkService
        self.fileService = fileService
        self.videoProcessingService = videoProcessingService
    }

    // MARK: - Public Methods

    func fetchHelloWorld() {
        Task {
            do {
                let message = try await networkService.fetchHelloWorld()
                helloWorldMessage = message
            } catch {
                helloWorldMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    func uploadVideo() {
        guard let videoURL = videoURL else {
            uploadStatus = "Please select a video first."
            return
        }

        uploadTask = Task {
            do {
                isUploading = true
                uploadStatus = "Preparing upload..."
                uploadProgress = 0.0

                let fileResponse = try await networkService.uploadVideo(from: videoURL) { progress in
                    self.uploadProgress = progress
                    let percentage = Int(progress * 100)
                    self.uploadStatus = "Uploading video... \(percentage)%"
                }

                // Check if task was cancelled
                if Task.isCancelled {
                    uploadStatus = "Upload cancelled"
                    isUploading = false
                    return
                }

                uploadStatus = "Upload successful! Ready to download results."
                downloadURL = fileResponse.download_url
                isUploading = false
                uploadProgress = 1.0

            } catch {
                if error is CancellationError {
                    uploadStatus = "Upload cancelled"
                } else {
                    uploadStatus = "Upload failed: \(error.localizedDescription)"
                }
                isUploading = false
                uploadProgress = 0.0
            }
        }
    }

    func cancelUpload() {
        uploadTask?.cancel()
        uploadTask = nil
        isUploading = false
        uploadProgress = 0.0
        uploadStatus = "Upload cancelled by user"
    }

    func downloadAndProcessResults() {
        guard !downloadURL.isEmpty else { return }

        downloadTask = Task {
            do {
                isDownloading = true
                downloadProgress = 0.0
                uploadStatus = "Starting download..."

                let zipURL = try await networkService.downloadFile(from: downloadURL) { progress in
                    self.downloadProgress = progress
                    let percentage = Int(progress * 100)
                    self.uploadStatus = "Downloading results... \(percentage)%"
                }

                await processDownloadedFile(zipURL)

            } catch {
                if !(error is CancellationError) {
                    uploadStatus = "Download failed: \(error.localizedDescription)"
                }
                isDownloading = false
                downloadProgress = 0.0
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = 0.0
        uploadStatus = "Download cancelled"
    }

    func selectVideo(url: URL) {
        Task {
            do {
                // Clear any previous status and progress
                uploadStatus = ""
                uploadProgress = 0.0

                // Verify the file exists before processing
                guard FileManager.default.fileExists(atPath: url.path) else {
                    uploadStatus = "Error: Selected video file not found"
                    return
                }

                uploadStatus = "Processing video..."
                let processedURL = try await videoProcessingService.processVideo(from: url)
                videoURL = processedURL
                uploadStatus = "Video ready for upload (\(formatVideoInfo(url: processedURL)))"

            } catch {
                uploadStatus = "Error processing video: \(error.localizedDescription)"
                print("Video processing error: \(error)")
            }
        }
    }

    // MARK: - Private Methods

    private func processDownloadedFile(_ zipURL: URL) async {
        do {
            uploadStatus = "Extracting files..."

            // Create extraction path and cleanup old extractions
            let extractPath = fileService.createUniqueExtractionPath()
            fileService.cleanupOldExtractions()

            // Extract zip file
            let success = try await fileService.extractZipFile(from: zipURL, to: extractPath)

            guard success else {
                uploadStatus = "Failed to extract files"
                isDownloading = false
                downloadProgress = 0.0
                return
            }

            uploadStatus = "Organizing images..."

            // Organize images into folders
            let organizedFolders = try await fileService.organizeImagesIntoFolders(at: extractPath)

            guard !organizedFolders.isEmpty else {
                uploadStatus = "No images found in the archive"
                isDownloading = false
                downloadProgress = 0.0
                return
            }

            // Save the download and update UI
            fileService.saveDownloadedFolder(at: extractPath)

            folders = organizedFolders
            let totalImages = folders.reduce(0) { $0 + $1.images.count }
            uploadStatus = "Success! Found \(totalImages) images in \(folders.count) folders"
            showGallery = true
            isDownloading = false
            downloadProgress = 1.0

        } catch {
            uploadStatus = "Error processing downloaded file: \(error.localizedDescription)"
            isDownloading = false
            downloadProgress = 0.0
        }
    }

    // Helper function to format video information
    private func formatVideoInfo(url: URL) -> String {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return formatter.string(fromByteCount: fileSize)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return url.lastPathComponent
    }
}
