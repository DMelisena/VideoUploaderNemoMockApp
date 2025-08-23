import SwiftUI
import PhotosUI

public struct ContentView: View {
    @State private var videoURL: URL?
    @State private var isPickerPresented = false
    @State private var uploadStatus = ""
    @State private var helloWorldMessage = "Tap the button to fetch data."
    private let networkManager = NetworkManager()

    public init() {}

    public var body: some View {
        VStack {
            Text(helloWorldMessage)
                .padding()
            Button("Server Test") {
                networkManager.fetchHelloWorld { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let text):
                            self.helloWorldMessage = text
                        case .failure(let error):
                            self.helloWorldMessage = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }

            if let videoURL = videoURL {
                Text("Selected video: \(videoURL.lastPathComponent)")
                    .padding()
            }

            Button("Select Video") {
                isPickerPresented = true
            }
            .padding()

            Button("Upload Video") {
                uploadVideo()
            }
            .padding()
            .disabled(videoURL == nil)

            Text(uploadStatus)
                .padding()
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoPicker(videoURL: $videoURL)
        }
    }

    private func uploadVideo() {
        guard let videoURL = videoURL else {
            uploadStatus = "Please select a video first."
            return
        }

        uploadStatus = "Uploading..."

        // IMPORTANT: Replace with your computer's IP address if running on a real device
        let url = URL(string: "https://prime-whole-fish.ngrok-free.app/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            uploadStatus = "Error reading video data: \(error.localizedDescription)"
            return
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(videoURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    uploadStatus = "Upload failed: \(error.localizedDescription)"
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    uploadStatus = "Upload failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    return
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8), responseString == "1" {
                    uploadStatus = "Upload successful!"
                } else {
                    uploadStatus = "Upload failed with unknown error."
                }
            }
        }.resume()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
