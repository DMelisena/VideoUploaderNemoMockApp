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
    let path: String // Add path for debugging
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
    @State private var debugInfo = "" // Add debug info state

    private let networkManager = NetworkManager()

    public init() {}

    @State private var downloadTask: URLSessionDownloadTask?
    @State private var progressObserver: NSKeyValueObservation?

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

            // Show debug info if available
            if !debugInfo.isEmpty {
                ScrollView {
                    Text(debugInfo)
                        .font(.caption)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 100)
            }

            // Download progress bar and cancel button
            if isDownloading {
                VStack {
                    HStack {
                        ProgressView("Downloading...", value: downloadProgress, total: 1.0)

                        Button("Cancel") {
                            downloadTask?.cancel()
                            progressObserver?.invalidate()
                            progressObserver = nil
                            isDownloading = false
                            uploadStatus = "Download cancelled"
                        }
                        .padding(.leading, 8)
                        .foregroundColor(.red)
                    }
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
                    debugInfo = "" // Clear debug info when going back
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

                            Spacer()

                            // Show folder path for debugging
                            Text(folder.path.replacingOccurrences(of: "/", with: "/\n"))
                                .font(.system(size: 8))
                                .foregroundColor(.blue)
                                .multilineTextAlignment(.trailing)
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
        debugInfo = ""

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
                        downloadURL = "https://prime-whole-fish.ngrok-free.app" + fileResponse.download_url
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
        uploadStatus = "Starting download..."
        debugInfo = ""

        downloadWithRetry(url: url, maxRetries: 3)
    }

    private func downloadWithRetry(url: URL, maxRetries: Int, currentRetry: Int = 0) {
        var request = URLRequest(url: url)
        request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        request.timeoutInterval = 300 // 5 minutes timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600 // 10 minutes total
        config.waitsForConnectivity = true

        let session = URLSession(configuration: config)

        let downloadTaskInstance = session.downloadTask(with: request) { localURL, _, error in
            DispatchQueue.main.async {
                // Clear the download task reference and observer
                self.downloadTask = nil
                self.progressObserver?.invalidate()
                self.progressObserver = nil

                if let error = error as NSError? {
                    // Check if it was cancelled by user
                    if error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
                        self.isDownloading = false
                        self.uploadStatus = "Download cancelled by user"
                        return
                    }

                    // Check if it's a network timeout or connection lost error
                    if error.domain == NSURLErrorDomain,
                       error.code == NSURLErrorTimedOut ||
                       error.code == NSURLErrorNetworkConnectionLost ||
                       error.code == NSURLErrorNotConnectedToInternet,
                       currentRetry < maxRetries
                    {
                        self.uploadStatus = "Connection lost. Retrying (\(currentRetry + 1)/\(maxRetries))..."

                        // Wait a bit before retrying
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.downloadWithRetry(url: url, maxRetries: maxRetries, currentRetry: currentRetry + 1)
                        }
                        return
                    } else {
                        self.isDownloading = false
                        self.uploadStatus = "Download failed: \(error.localizedDescription)"
                        if currentRetry >= maxRetries {
                            self.uploadStatus += " (Max retries reached)"
                        }
                        return
                    }
                }

                self.isDownloading = false

                guard let localURL = localURL else {
                    self.uploadStatus = "Download failed: No file received"
                    return
                }

                // Check if we actually got a file
                do {
                    let fileSize = try localURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    if fileSize == 0 {
                        self.uploadStatus = "Download failed: Empty file received"
                        return
                    }
                    self.uploadStatus = "Download complete. Extracting files..."
                } catch {
                    self.uploadStatus = "Download failed: Could not verify file"
                    return
                }

                // Unzip the file
                self.unzipAndOrganizeImages(from: localURL)
            }
        }

        // Store the download task for potential cancellation
        downloadTask = downloadTaskInstance

        // Add progress tracking
        progressObserver = downloadTaskInstance.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                self.downloadProgress = progress.fractionCompleted
                if progress.fractionCompleted > 0 {
                    let mbDownloaded = Double(progress.completedUnitCount) / 1024.0 / 1024.0
                    let mbTotal = Double(progress.totalUnitCount) / 1024.0 / 1024.0
                    self.uploadStatus = String(format: "Downloading... %.1f/%.1f MB (%.0f%%)",
                                               mbDownloaded, mbTotal, progress.fractionCompleted * 100)
                }
            }
        }

        downloadTaskInstance.resume()
    }

    private func unzipAndOrganizeImages(from zipURL: URL) {
        uploadStatus = "Extracting files..."

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let extractPath = documentsPath.appendingPathComponent("ExtractedImages_\(UUID().uuidString.prefix(8))")

        do {
            // Clean up any previous extractions (keep only most recent 3)
            let existingExtractions = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.lastPathComponent.hasPrefix("ExtractedImages_") }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }

            // Remove old extractions, keep only 2 most recent
            if existingExtractions.count > 2 {
                for oldExtraction in existingExtractions.dropFirst(2) {
                    try? FileManager.default.removeItem(at: oldExtraction)
                }
            }

            // Create extraction directory
            try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)

            // Check if ZIP file exists and is valid
            guard FileManager.default.fileExists(atPath: zipURL.path) else {
                uploadStatus = "Error: ZIP file not found"
                return
            }

            // Check file size
            let attributes = try FileManager.default.attributesOfItem(atPath: zipURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            if fileSize == 0 {
                uploadStatus = "Error: ZIP file is empty"
                return
            }

            uploadStatus = "Extracting ZIP file (\(ByteCountFormatter().string(fromByteCount: fileSize)))..."

            // Unzip using ZipArchive with error checking
            let success = SSZipArchive.unzipFile(
                atPath: zipURL.path,
                toDestination: extractPath.path,
                progressHandler: { _, _, entryNumber, total in
                    DispatchQueue.main.async {
                        self.uploadStatus = "Extracting: \(entryNumber + 1)/\(total) files"
                    }
                },
                completionHandler: { _, succeeded, error in
                    DispatchQueue.main.async {
                        if succeeded {
                            self.uploadStatus = "Extraction complete. Organizing images..."
                            // Small delay to let user see the completion message
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.organizeImagesIntoFolders(at: extractPath)
                            }
                        } else {
                            self.uploadStatus = "Extraction failed: \(error?.localizedDescription ?? "Unknown error")"
                        }
                    }
                }
            )

            if !success {
                uploadStatus = "Failed to start extraction"
            }

        } catch {
            uploadStatus = "Error preparing extraction: \(error.localizedDescription)"
        }
    }

    private func organizeImagesIntoFolders(at path: URL) {
        var tempFolders: [FolderItem] = []
        var debugMessages: [String] = []

        do {
            // Verify the extraction path exists
            guard FileManager.default.fileExists(atPath: path.path) else {
                uploadStatus = "Error: Extracted folder not found"
                return
            }

            debugMessages.append("📁 Scanning: \(path.lastPathComponent)")

            // Recursively scan all directories
            tempFolders = scanDirectoryRecursively(at: path, relativeTo: path, debugMessages: &debugMessages)

            // Update debug info
            debugInfo = debugMessages.joined(separator: "\n")

            let totalImages = tempFolders.reduce(0) { $0 + $1.images.count }

            if tempFolders.isEmpty {
                uploadStatus = "No image folders found in the archive"
                debugInfo += "\n❌ No folders with images found"
                return
            }

            folders = tempFolders
            uploadStatus = "Success! Found \(totalImages) images in \(tempFolders.count) folders"
            showGallery = true

        } catch {
            uploadStatus = "Error organizing images: \(error.localizedDescription)"
            debugInfo = "Error: \(error.localizedDescription)"
            print("Error organizing images: \(error)")
        }
    }

    private func scanDirectoryRecursively(at currentPath: URL, relativeTo basePath: URL, debugMessages: inout [String]) -> [FolderItem] {
        var folderItems: [FolderItem] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: currentPath, includingPropertiesForKeys: [.isDirectoryKey, .fileResourceTypeKey])

            var allFiles: [String] = []
            var directories: [URL] = []
            var imageFiles: [URL] = []
            var otherFiles: [String] = []

            // Categorize all items in this directory
            for item in contents {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)

                allFiles.append(item.lastPathComponent)

                if isDirectory.boolValue {
                    directories.append(item)
                } else if isImageFile(item) {
                    imageFiles.append(item)
                } else {
                    otherFiles.append(item.lastPathComponent)
                }
            }

            // Create relative path for display
            let relativePath = currentPath.path.replacingOccurrences(of: basePath.path, with: "")
            let displayPath = relativePath.isEmpty ? "Root" : relativePath

            debugMessages.append("\n📂 \(displayPath)")
            debugMessages.append("   📄 All files (\(allFiles.count)): \(allFiles.joined(separator: ", "))")
            debugMessages.append("   🖼️ Image files (\(imageFiles.count)): \(imageFiles.map { $0.lastPathComponent }.joined(separator: ", "))")
            debugMessages.append("   📁 Directories (\(directories.count)): \(directories.map { $0.lastPathComponent }.joined(separator: ", "))")
            debugMessages.append("   ❌ Ignored files (\(otherFiles.count)): \(otherFiles.joined(separator: ", "))")

            // If current directory has images, create a folder item
            if !imageFiles.isEmpty {
                let imageItems = imageFiles.map { ImageItem(name: $0.lastPathComponent, url: $0) }
                    .sorted { $0.name < $1.name }

                let folderName = relativePath.isEmpty ? "Root Images" : currentPath.lastPathComponent
                let folderItem = FolderItem(
                    name: folderName,
                    images: imageItems,
                    path: displayPath
                )
                folderItems.append(folderItem)

                debugMessages.append("   ✅ Created folder: '\(folderName)' with \(imageItems.count) images")
            }

            // Recursively process subdirectories
            for directory in directories {
                let subfolders = scanDirectoryRecursively(at: directory, relativeTo: basePath, debugMessages: &debugMessages)
                folderItems.append(contentsOf: subfolders)
            }

        } catch {
            debugMessages.append("❌ Error scanning \(currentPath.lastPathComponent): \(error.localizedDescription)")
        }

        return folderItems
    }

    private func isImageFile(_ url: URL) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic", "heif"]
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
