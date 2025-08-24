import SwiftUI

struct DownloadedFilesView: View {
    @Binding var showDownloadedFiles: Bool
    @State private var downloadedFolders: [URL] = []

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("Back") {
                        showDownloadedFiles = false
                    }
                    .padding()

                    Spacer()

                    Text("Downloaded Files")
                        .font(.title)
                        .fontWeight(.semibold)

                    Spacer()

                    // Empty space for symmetry
                    Button("") {}
                        .disabled(true)
                        .opacity(0)
                        .padding()
                }

                if downloadedFolders.isEmpty {
                    Spacer()
                    Text("No downloaded files yet")
                        .foregroundColor(.gray)
                        .font(.body)
                    Spacer()
                } else {
                    List(downloadedFolders, id: \.self) { folderURL in
                        NavigationLink(destination: DownloadedGalleryView(rootURL: folderURL)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folderURL.lastPathComponent)
                                    .font(.headline)
                                Text("Tap to view images")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: loadDownloadedFolders)
    }

    private func loadDownloadedFolders() {
        let defaults = UserDefaults.standard
        if let downloadedPaths = defaults.array(forKey: "downloadedFolders") as? [String] {
            downloadedFolders = downloadedPaths.compactMap { path in
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
        }
    }
}

struct DownloadedGalleryView: View {
    let rootURL: URL
    @State private var folders: [FolderItem] = []
    @State private var debugInfo = ""
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading images...")
                    .padding()
            } else if folders.isEmpty {
                Text("No images found in this download.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(folders, id: \.id) { folder in
                    NavigationLink(destination: DownloadedFolderDetailView(folder: folder)) {
                        HStack {
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
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(rootURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            organizeImagesIntoFolders(at: rootURL)
        }
    }

    private func organizeImagesIntoFolders(at path: URL) {
        isLoading = true
        var tempFolders: [FolderItem] = []
        var debugMessages: [String] = []

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard FileManager.default.fileExists(atPath: path.path) else {
                    DispatchQueue.main.async {
                        self.debugInfo = "Error: Extracted folder not found"
                        self.isLoading = false
                    }
                    return
                }

                debugMessages.append("📁 Scanning: \(path.lastPathComponent)")
                tempFolders = self.scanDirectoryRecursively(at: path, relativeTo: path, debugMessages: &debugMessages)
                let totalImages = tempFolders.reduce(0) { $0 + $1.images.count }

                DispatchQueue.main.async {
                    if tempFolders.isEmpty {
                        self.debugInfo += "\n❌ No folders with images found"
                    } else {
                        self.folders = tempFolders
                        self.debugInfo = "Success! Found \(totalImages) images in \(tempFolders.count) folders"
                    }
                    self.isLoading = false
                }

            } catch {
                DispatchQueue.main.async {
                    self.debugInfo = "Error organizing images: \(error.localizedDescription)"
                    self.isLoading = false
                }
                print("Error organizing images: \(error)")
            }
        }
    }

    private func scanDirectoryRecursively(at currentPath: URL, relativeTo basePath: URL, debugMessages: inout [String]) -> [FolderItem] {
        var folderItems: [FolderItem] = []

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: currentPath, includingPropertiesForKeys: [.isDirectoryKey, .fileResourceTypeKey])

            var imageFiles: [URL] = []
            var directories: [URL] = []

            for item in contents {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: item.path, isDirectory: &isDirectory)

                if isDirectory.boolValue {
                    directories.append(item)
                } else if isImageFile(item) {
                    imageFiles.append(item)
                }
            }

            let relativePath = currentPath.path.replacingOccurrences(of: basePath.path, with: "")
            let displayPath = relativePath.isEmpty ? "Root" : relativePath

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
            }

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

// MARK: - Downloaded Folder Detail View

struct DownloadedFolderDetailView: View {
    let folder: FolderItem
    @State private var selectedImage: ImageItem?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
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
        .sheet(item: $selectedImage) { image in
            DownloadedImageDetailView(image: image)
        }
    }
}

// MARK: - Downloaded Image Detail View

struct DownloadedImageDetailView: View {
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

