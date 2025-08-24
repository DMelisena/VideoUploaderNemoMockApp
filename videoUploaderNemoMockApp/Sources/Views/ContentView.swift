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
            Text(viewModel.helloWorldMessage)
                .padding()

            Button("Server Test") {
                viewModel.fetchHelloWorld()
            }

            if let videoURL = viewModel.videoURL {
                Text("Selected video: \(videoURL.lastPathComponent)")
                    .padding()
            }

            Button("Select Video") {
                isPickerPresented = true
            }
            .padding()

            Button("Upload Video") {
                viewModel.uploadVideo()
            }
            .padding()
            .disabled(viewModel.videoURL == nil || viewModel.isUploading)

            if viewModel.isUploading {
                VStack {
                    ProgressView("Uploading...", value: viewModel.uploadProgress, total: 1.0)
                    Text("\(Int(viewModel.uploadProgress * 100))%")
                        .font(.caption)
                }
                .padding()
            }

            Text(viewModel.uploadStatus)
                .padding()

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

            if viewModel.isDownloading {
                VStack {
                    HStack {
                        ProgressView("Downloading...", value: viewModel.downloadProgress, total: 1.0)

                        Button("Cancel") {
                            viewModel.cancelDownload()
                        }
                        .padding(.leading, 8)
                        .foregroundColor(.red)
                    }
                    .padding()

                    Text("\(Int(viewModel.downloadProgress * 100))%")
                        .font(.caption)
                }
            }

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
        .sheet(isPresented: $isPickerPresented) {
            VideoPicker { url in
                viewModel.selectVideo(url: url)
            }
        }
    }
}

#Preview {
    ContentView()
}
