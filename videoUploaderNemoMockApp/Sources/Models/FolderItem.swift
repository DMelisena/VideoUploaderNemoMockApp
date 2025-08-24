import Foundation

struct FolderItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let images: [ImageItem]
    let path: String
}
