import SwiftUI

struct FolderDetailView: View {
    let folder: FolderItem
    @StateObject private var viewModel: GalleryViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    init(folder: FolderItem) {
        self.folder = folder
        self._viewModel = StateObject(wrappedValue: GalleryViewModel(folders: [folder]))
    }
    
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
                            viewModel.selectImage(image)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: $viewModel.selectedImage) { image in
            ImageDetailView(image: image) {
                viewModel.clearSelection()
            }
        }
    }
}

#Preview {
    FolderDetailView(
        folder: FolderItem(
            name: "Sample Folder",
            images: [
                ImageItem(name: "image1.jpg", url: URL(fileURLWithPath: "/tmp/image1.jpg")),
                ImageItem(name: "image2.jpg", url: URL(fileURLWithPath: "/tmp/image2.jpg"))
            ],
            path: "/sample/path"
        )
    )
}
