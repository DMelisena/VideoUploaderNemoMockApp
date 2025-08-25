import Foundation

protocol NetworkServiceProtocol {
    func fetchHelloWorld() async throws -> String
    func uploadVideo(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> FileResponse
    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL
}

class NetworkService: NetworkServiceProtocol {
    private let baseURL = "https://prime-whole-fish.ngrok-free.app"

    // Create a custom URLSession with better configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 1200
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.networkServiceType = .default

        // Add retry mechanism for connection issues
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        return URLSession(configuration: config)
    }()

    func fetchHelloWorld() async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, _) = try await urlSession.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["status"] as? String
        else {
            throw NetworkError.invalidResponse
        }

        return message
    }

    func uploadVideo(from videoURL: URL, progressHandler: @escaping (Double) -> Void) async throws -> FileResponse {
        guard let url = URL(string: "\(baseURL)/upload") else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.timeoutInterval = 600 // Increased timeout for large files

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData = try Data(contentsOf: videoURL)
        let body = createMultipartBody(boundary: boundary, videoData: videoData, fileName: videoURL.lastPathComponent)

        // Create a custom URLSession with configuration for better progress tracking
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600
        config.timeoutIntervalForResource = 1200
        let session = URLSession(configuration: config)

        // Use URLSessionUploadTask for progress tracking with cancellation support
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var uploadTask: URLSessionUploadTask?
                var progressObserver: NSKeyValueObservation?
                var totalObserver: NSKeyValueObservation?
                var completedObserver: NSKeyValueObservation?

                uploadTask = session.uploadTask(with: request, from: body) { data, response, error in
                    // Clean up observers when task completes
                    progressObserver?.invalidate()
                    totalObserver?.invalidate()
                    completedObserver?.invalidate()

                    // Check for cancellation first
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    if let error = error {
                        print("Upload error: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: NetworkError.invalidResponse)
                        return
                    }

                    print("Upload response status: \(httpResponse.statusCode)")

                    guard (200 ... 299).contains(httpResponse.statusCode) else {
                        let errorMsg = "HTTP \(httpResponse.statusCode)"
                        continuation.resume(throwing: NetworkError.uploadFailed(errorMsg))
                        return
                    }

                    guard let data = data else {
                        continuation.resume(throwing: NetworkError.noData)
                        return
                    }

                    do {
                        let fileResponse = try JSONDecoder().decode(FileResponse.self, from: data)
                        continuation.resume(returning: fileResponse)
                    } catch {
                        print("Decode error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }

                // Enhanced progress observation - store observers in local variables
                if let task = uploadTask {
                    progressObserver = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
                        let currentProgress = progress.fractionCompleted
                        DispatchQueue.main.async {
                            if !Task.isCancelled {
                                // Ensure progress never goes backward and is between 0 and 1
                                let clampedProgress = max(0.0, min(1.0, currentProgress))
                                progressHandler(clampedProgress)
                                print("Upload progress: \(Int(clampedProgress * 100))%")
                            }
                        }
                    }

                    // Also observe total unit count and completed unit count for more granular progress
                    totalObserver = task.progress.observe(\.totalUnitCount, options: [.new]) { progress, _ in
                        print("Upload total bytes: \(progress.totalUnitCount)")
                    }

                    completedObserver = task.progress.observe(\.completedUnitCount, options: [.new]) { progress, _ in
                        if progress.totalUnitCount > 0 {
                            let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                            print("Upload bytes completed: \(progress.completedUnitCount)/\(progress.totalUnitCount) (\(Int(percentage * 100))%)")
                        }
                    }

                    task.resume()
                    print("Upload task started for file: \(videoURL.lastPathComponent)")
                }

                // Handle cancellation
                if Task.isCancelled {
                    progressObserver?.invalidate()
                    totalObserver?.invalidate()
                    completedObserver?.invalidate()
                    uploadTask?.cancel()
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            // This will be called if the task is cancelled
            print("Upload task was cancelled")
        }
    }

    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var downloadTask: URLSessionDownloadTask?
                var progressObserver: NSKeyValueObservation?

                downloadTask = urlSession.downloadTask(with: request) { localURL, _, error in
                    // Clean up observer when task completes
                    progressObserver?.invalidate()

                    // Check for cancellation first
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                        return
                    }

                    if let error = error {
                        print("Download error: \(error)")
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let localURL = localURL else {
                        continuation.resume(throwing: NetworkError.noData)
                        return
                    }

                    print("Download completed: \(localURL.path)")
                    continuation.resume(returning: localURL)
                }

                // Enhanced progress observation for download
                if let task = downloadTask {
                    progressObserver = task.progress.observe(\.fractionCompleted, options: [.new]) { progress, _ in
                        let currentProgress = progress.fractionCompleted
                        DispatchQueue.main.async {
                            if !Task.isCancelled {
                                let clampedProgress = max(0.0, min(1.0, currentProgress))
                                progressHandler(clampedProgress)
                                print("Download progress: \(Int(clampedProgress * 100))%")
                            }
                        }
                    }

                    task.resume()
                    print("Download task started for: \(urlString)")
                }

                // Handle cancellation
                if Task.isCancelled {
                    progressObserver?.invalidate()
                    downloadTask?.cancel()
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            // This will be called if the task is cancelled
            print("Download task was cancelled")
        }
    }

    private func createMultipartBody(boundary: String, videoData: Data, fileName: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case uploadFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .noData:
            return "No data received"
        case let .uploadFailed(message):
            return "Upload failed: \(message)"
        case let .downloadFailed(message):
            return "Download failed: \(message)"
        }
    }
}
