import Foundation
import SwiftUI

 @MainActor
class DownloadedFilesViewModel: ObservableObject {
    @Published var downloadedFolders: [URL] = []
    @Published var selectedFolderData: [FolderItem] = []
    @Published var isLoading = false
    
    private let fileService: FileServiceProtocol
    
    init(fileService: FileServiceProtocol = FileService()) {
        self.fileService = fileService
    }
    
    func loadDownloadedFolders() {
        downloadedFolders = fileService.getDownloadedFolders()
    }
    
    func loadFolderData(for folderURL: URL) {
        Task {
            isLoading = true
            do {
                selectedFolderData = try await fileService.organizeImagesIntoFolders(at: folderURL)
            } catch {
                print("Error loading folder data: \(error)")
                selectedFolderData = []
            }
            isLoading = false
        }
    }
}
