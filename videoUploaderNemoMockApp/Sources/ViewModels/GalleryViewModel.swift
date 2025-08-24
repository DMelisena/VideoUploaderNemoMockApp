import Foundation
import SwiftUI

 @MainActor
class GalleryViewModel: ObservableObject {
    @Published var folders: [FolderItem]
    @Published var selectedImage: ImageItem?
    
    init(folders: [FolderItem]) {
        self.folders = folders
    }
    
    func selectImage(_ image: ImageItem) {
        selectedImage = image
    }
    
    func clearSelection() {
        selectedImage = nil
    }
}
