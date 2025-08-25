import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var isPickerPresented = false

    var body: some View {
        if viewModel.showDownloadedFiles {
            DownloadedFilesView(showDownloadedFiles: $viewModel.showDownloadedFiles)
        } else {
            NavigationView {
                VStack {
                    if !viewModel.showGallery {
                        uploadInterfaceView
                    } else {
                        GalleryView(
                            folders: viewModel.folders,
                            showGallery: $viewModel.showGallery
                        )
                    }
                }
                .navigationTitle(viewModel.showGallery ? "Gallery" : "Video Processor")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Downloads") {
                            viewModel.showDownloadedFiles = true
                        }
                    }
                }
            }
        }
    }

    private var uploadInterfaceView: some View {
        VStack(spacing: 16) {
            serverTestSection
            videoSelectionSection
            uploadSection
            uploadProgressSection
            statusSection
            debugSection
            downloadProgressSection
            downloadSection
        }
        .sheet(isPresented: $isPickerPresented) {
            VideoPicker { url in
                viewModel.selectVideo(url: url)
            }
        }
    }

    private var serverTestSection: some View {
        VStack(spacing: 12) {
            Text(viewModel.helloWorldMessage)
                .padding()

            Button("Server Test") {
                viewModel.fetchHelloWorld()
            }
        }
    }

    private var videoSelectionSection: some View {
        VStack(spacing: 12) {
            if let videoURL = viewModel.videoURL {
                Text("Selected video: \(videoURL.lastPathComponent)")
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }

            Button("Select Video") {
                isPickerPresented = true
            }
            .padding()
        }
    }

    private var uploadSection: some View {
        Button("Upload Video") {
            viewModel.uploadVideo()
        }
        .padding()
        .disabled(viewModel.videoURL == nil || viewModel.isUploading)
    }

    private var uploadProgressSection: some View {
        Group {
            if viewModel.isUploading {
                uploadProgressView
            }
        }
    }

    private var uploadProgressView: some View {
        VStack(spacing: 12) {
            Text("Uploading Video")
                .font(.headline)
                .foregroundColor(.primary)

            progressBarView
            fileSizeProgressView
            cancelUploadButton
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var progressBarView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.uploadProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle())
                .scaleEffect(x: 1, y: 2, anchor: .center)
                .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)

            HStack {
                Text("Progress:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
    }

    @ViewBuilder
    private var fileSizeProgressView: some View {
        if let videoURL = viewModel.videoURL,
           let fileSize = getFileSize(url: videoURL)
        {
            let uploadedSize = Int64(Double(fileSize) * viewModel.uploadProgress)

            HStack {
                Text("Uploaded:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(formatBytes(uploadedSize)) of \(formatBytes(fileSize))")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }

    private var cancelUploadButton: some View {
        Button("Cancel Upload") {
            viewModel.cancelUpload()
        }
        .foregroundColor(.red)
        .font(.caption)
    }

    private var statusSection: some View {
        Text(viewModel.uploadStatus)
            .padding()
            .foregroundColor(statusColor)
    }

    private var statusColor: Color {
        if viewModel.uploadStatus.contains("Error") || viewModel.uploadStatus.contains("failed") {
            return .red
        }
        return .primary
    }

    @ViewBuilder
    private var debugSection: some View {
        if !viewModel.debugInfo.isEmpty {
            ScrollView {
                Text(viewModel.debugInfo)
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 100)
        }
    }

    @ViewBuilder
    private var downloadProgressSection: some View {
        if viewModel.isDownloading {
            downloadProgressView
        }
    }

    private var downloadProgressView: some View {
        VStack(spacing: 12) {
            Text("Downloading Results")
                .font(.headline)
                .foregroundColor(.primary)

            downloadProgressBarView
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    private var downloadProgressBarView: some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView(value: viewModel.downloadProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)

                Button("Cancel") {
                    viewModel.cancelDownload()
                }
                .padding(.leading, 8)
                .foregroundColor(.red)
                .font(.caption)
            }

            HStack {
                Text("Download Progress:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(viewModel.downloadProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
    }

    @ViewBuilder
    private var downloadSection: some View {
        if !viewModel.downloadURL.isEmpty && !viewModel.isDownloading {
            Button("Download & View Results") {
                viewModel.downloadAndProcessResults()
            }
            .padding()
            .foregroundColor(.white)
            .background(Color.green)
            .cornerRadius(8)
        }
    }

    // Helper function to get file size
    private func getFileSize(url: URL) -> Int64? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return fileAttributes[.size] as? Int64
        } catch {
            return nil
        }
    }

    // Helper function to format bytes
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    ContentView()
}
