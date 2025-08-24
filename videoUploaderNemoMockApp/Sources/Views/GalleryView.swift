import SwiftUI

struct GalleryView: View {
    let folders: [FolderItem]
    @Binding var showGallery: Bool
    
    var body: some View {
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
                        FolderRowView(folder: folder)
                    }
                }
            }
        }
    }
}

struct FolderRowView: View {
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
            
            Text(folder.path.replacingOccurrences(of: "/", with: "/\n"))
                .font(.system(size: 8))
                .foregroundColor(.blue)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GalleryView(
        folders: [
            FolderItem(
                name: "Sample Folder",
                images: [
                    ImageItem(name: "image1.jpg", url: URL(fileURLWithPath: "/tmp/image1.jpg"))
                ],
                path: "/sample/path"
            )
        ],
        showGallery: .constant(true)
    )
}
