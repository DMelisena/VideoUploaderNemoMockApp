import SwiftUI

struct DownloadedGalleryView: View {
    let rootURL: URL
    @ObservedObject var viewModel: DownloadedFilesViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading images...")
                    .padding()
            } else if viewModel.selectedFolderData.isEmpty {
                Text("No images found in this download.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(viewModel.selectedFolderData, id: \.id) { folder in
                    NavigationLink(destination: DownloadedFolderDetailView(folder: folder)) {
                        DownloadedFolderRowView(folder: folder)
                    }
                }
            }
        }
        .navigationTitle(rootURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadFolderData(for: rootURL)
        }
    }
}

struct DownloadedFolderRowView: View {
    let folder: FolderItem
    
    var body: some View {
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
            ImageDetailView(image: image) {
                selectedImage = nil
            }
        }
    }
}

#Preview {
    DownloadedGalleryView(
        rootURL: URL(fileURLWithPath: "/tmp/sample"),
        viewModel: DownloadedFilesViewModel()
    )
}
