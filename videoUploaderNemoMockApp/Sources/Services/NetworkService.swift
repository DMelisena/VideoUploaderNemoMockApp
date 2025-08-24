import Foundation

protocol NetworkServiceProtocol {
    func fetchHelloWorld() async throws -> String
    func uploadVideo(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> FileResponse
    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL
}

class NetworkService: NetworkServiceProtocol {
    private let baseURL = "https://prime-whole-fish.ngrok-free.app"
    
    func fetchHelloWorld() async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["status"] as? String else {
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
        request.timeoutInterval = 300
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let videoData = try Data(contentsOf: videoURL)
        let body = createMultipartBody(boundary: boundary, videoData: videoData, fileName: videoURL.lastPathComponent)
        
        // Use URLSessionUploadTask for progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
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
                    continuation.resume(throwing: error)
                }
            }
            
            // Progress observation
            let _ = task.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    progressHandler(progress.fractionCompleted)
                }
            }
            
            task.resume()
        }
    }
    
    func downloadFile(from urlString: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.timeoutInterval = 300
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let localURL = localURL else {
                    continuation.resume(throwing: NetworkError.noData)
                    return
                }
                
                continuation.resume(returning: localURL)
            }
            
            let _ = task.progress.observe(\.fractionCompleted) { progress, _ in
                DispatchQueue.main.async {
                    progressHandler(progress.fractionCompleted)
                }
            }
            
            task.resume()
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
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
