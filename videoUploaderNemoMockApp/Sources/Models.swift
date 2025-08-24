import Foundation

// MARK: - Shared Data Models

struct FileResponse: Codable {
    let download_url: String
    let message: String
    let processing_time: String
}

struct FolderItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let images: [ImageItem]
    let path: String
}

struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}
