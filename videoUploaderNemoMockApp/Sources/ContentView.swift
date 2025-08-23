import PhotosUI
import SwiftUI
import ZipArchive

// Add struct to decode JSON response
struct FileResponse: Codable {
    let download_url: String
    let message: String
    let processing_time: String
}

struct FolderItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let images: [ImageItem]
}

struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}

public struct ContentView: View {
    @State private var videoURL: URL?
    @State private var isPickerPresented = false
    @State private var uploadStatus = ""
    @State private var downloadURL = ""
    @State private var helloWorldMessage = "Tap the button to fetch data."
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    @State private var folders: [FolderItem] = []
    @State private var showGallery = false

    private let networkManager = NetworkManager()

    public init() {}

    public var body: some View {
        NavigationView {
            VStack {
                if !showGallery {
                    // Original upload interface
                    uploadInterfaceView
                } else {
                    // Gallery view
                    galleryView
                }
            }
            .navigationTitle(showGallery ? "Gallery" : "Video Processor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var uploadInterfaceView: some View {
        VStack {
            Text(helloWorldMessage)
                .padding()

            Button("Server Test") {
                networkManager.fetchHelloWorld { result in
                    DispatchQueue.main.async {
                        switch result {
                        case let .success(text):
                            self.helloWorldMessage = text
                        case let .failure(error):
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

            // Download progress bar
            if isDownloading {
                VStack {
                    ProgressView("Downloading...", value: downloadProgress, total: 1.0)
                        .padding()
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption)
                }
            }

            // Download button if available
            if !downloadURL.isEmpty && !isDownloading {
                Button("Download & View Results") {
                    downloadAndUnzipFile()
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.green)
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoPicker(videoURL: $videoURL)
        }
    }

    private var galleryView: some View {
        VStack {
            HStack {
                Button("Back") {
                    showGallery = false
                }
                .padding()

                Spacer()

                Text("\(folders.count) folders")
                    .font(.caption)
                    .padding()
            }

            if folders.isEmpty {
                Text("No images found")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(folders, id: \.id) { folder in
                    NavigationLink(destination: FolderDetailView(folder: folder)) {
                        HStack {
                            // Show first image as thumbnail
                            if let firstImage = folder.images.first {
                                AsyncImage(url: firstImage.url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                            }

                            VStack(alignment: .leading) {
                                Text(folder.name)
                                    .font(.headline)
                                Text("\(folder.images.count) images")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func uploadVideo() {
        guard let videoURL = videoURL else {
            uploadStatus = "Please select a video first."
            return
        }

        uploadStatus = "Uploading..."
        downloadURL = ""
        folders = []
        showGallery = false

        let url = URL(string: "https://prime-whole-fish.ngrok-free.app/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

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

                guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
                    uploadStatus = "Upload failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)"
                    return
                }

                if let data = data {
                    do {
                        let fileResponse = try JSONDecoder().decode(FileResponse.self, from: data)
                        uploadStatus = "Upload successful! Ready to download results."
                        // Construct full download URL
                        downloadURL = fileResponse.download_url
                    } catch {
                        uploadStatus = "Upload successful but failed to parse response: \(error.localizedDescription)"
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("Raw response: \(responseString)")
                        }
                    }
                } else {
                    uploadStatus = "Upload completed but no response data."
                }
            }
        }.resume()
    }

    private func downloadAndUnzipFile() {
        guard let url = URL(string: downloadURL) else { return }

        isDownloading = true
        downloadProgress = 0.0

        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")

        URLSession.shared.downloadTask(with: request) { localURL, _, error in
            DispatchQueue.main.async {
                self.isDownloading = false

                if let error = error {
                    self.uploadStatus = "Download failed: \(error.localizedDescription)"
                    return
                }

                guard let localURL = localURL else {
                    self.uploadStatus = "Download failed: No file received"
                    return
                }

                // Unzip the file
                self.unzipAndOrganizeImages(from: localURL)
            }
        }.resume()
    }

    private func unzipAndOrganizeImages(from zipURL: URL) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extractPath = documentsPath.appendingPathComponent("ExtractedImages")

        // Clean up previous extractions
        try? FileManager.default.removeItem(at: extractPath)

        do {
            // Create extraction directory
            try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)

            // Unzip using ZipArchive (you'll need to add this dependency)
            let success = SSZipArchive.unzipFile(atPath: zipURL.path, toDestination: extractPath.path)

            if success {
                organizeImagesIntoFolders(at: extractPath)
                uploadStatus = "Processing complete! View your results below."
                showGallery = true
            } else {
                uploadStatus = "Failed to extract zip file"
            }
        } catch {
            uploadStatus = "Error extracting files: \(error.localizedDescription)"
        }
    }

    private func organizeImagesIntoFolders(at path: URL) {
        var tempFolders: [FolderItem] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)

            for item in contents {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory) else { continue }

                if isDirectory.boolValue {
                    // This is a folder, collect images from it
                    let images = collectImages(from: item)
                    if !images.isEmpty {
                        let folder = FolderItem(name: item.lastPathComponent, images: images)
                        tempFolders.append(folder)
                    }
                } else if isImageFile(item) {
                    // This is a loose image file, create a "Root" folder
                    let rootImages = collectImages(from: path, includeSubdirectories: false)
                    if !rootImages.isEmpty {
                        let rootFolder = FolderItem(name: "Root", images: rootImages)
                        tempFolders.insert(rootFolder, at: 0)
                    }
                    break // Only do this once
                }
            }

            folders = tempFolders
        } catch {
            print("Error organizing images: \(error)")
        }
    }

    private func collectImages(from folderURL: URL, includeSubdirectories: Bool = true) -> [ImageItem] {
        var images: [ImageItem] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)

            for item in contents {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)

                if isDirectory.boolValue, includeSubdirectories {
                    // Recursively collect from subdirectories
                    images.append(contentsOf: collectImages(from: item))
                } else if isImageFile(item) {
                    let imageItem = ImageItem(name: item.lastPathComponent, url: item)
                    images.append(imageItem)
                }
            }
        } catch {
            print("Error collecting images from \(folderURL): \(error)")
        }

        return images.sorted { $0.name < $1.name }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
}

// Folder detail view to show all images in a folder
struct FolderDetailView: View {
    let folder: FolderItem
    @State private var selectedImage: ImageItem?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(folder.images, id: \.id) { image in
                        AsyncImage(url: image.url) { loadedImage in
                            loadedImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedImage = image
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $selectedImage) { image in
            ImageDetailView(image: image)
        }
    }
}

// Full screen image viewer
struct ImageDetailView: View {
    let image: ImageItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            AsyncImage(url: image.url) { loadedImage in
                loadedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .navigationTitle(image.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
