import Foundation
import ZipArchive

protocol FileServiceProtocol {
    func extractZipFile(from zipURL: URL, to extractPath: URL) async throws -> Bool
    func organizeImagesIntoFolders(at path: URL) async throws -> [FolderItem]
    func saveDownloadedFolder(at path: URL)
    func getDownloadedFolders() -> [URL]
    func createUniqueExtractionPath() -> URL
    func cleanupOldExtractions()
}

class FileService: FileServiceProtocol {
    func extractZipFile(from zipURL: URL, to extractPath: URL) async throws -> Bool {
        try FileManager.default.createDirectory(at: extractPath, withIntermediateDirectories: true)
        
        return await withCheckedContinuation { continuation in
            let success = SSZipArchive.unzipFile(
                atPath: zipURL.path,
                toDestination: extractPath.path,
                progressHandler: nil,
                completionHandler: { _, succeeded, error in
                    continuation.resume(returning: succeeded)
                }
            )
            
            if !success {
                continuation.resume(returning: false)
            }
        }
    }
    
    func organizeImagesIntoFolders(at path: URL) async throws -> [FolderItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var debugMessages: [String] = []
                    let folders = self.scanDirectoryRecursively(
                        at: path,
                        relativeTo: path,
                        debugMessages: &debugMessages
                    )
                    continuation.resume(returning: folders)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func saveDownloadedFolder(at path: URL) {
        let defaults = UserDefaults.standard
        var downloadedPaths = defaults.array(forKey: "downloadedFolders") as? [String] ?? []
        downloadedPaths.append(path.path)
        defaults.set(downloadedPaths, forKey: "downloadedFolders")
    }
    
    func getDownloadedFolders() -> [URL] {
        let defaults = UserDefaults.standard
        guard let downloadedPaths = defaults.array(forKey: "downloadedFolders") as? [String] else {
            return []
        }
        
        return downloadedPaths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }
    
    func createUniqueExtractionPath() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("ExtractedImages_\(UUID().uuidString.prefix(8))")
    }
    
    func cleanupOldExtractions() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let existingExtractions = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey]
            )
            .filter { $0.lastPathComponent.hasPrefix("ExtractedImages_") }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            if existingExtractions.count > 2 {
                for oldExtraction in existingExtractions.dropFirst(2) {
                    try? FileManager.default.removeItem(at: oldExtraction)
                }
            }
        } catch {
            print("Error cleaning up old extractions: \(error)")
        }
    }
    
    private func scanDirectoryRecursively(
        at currentPath: URL,
        relativeTo basePath: URL,
        debugMessages: inout [String]
    ) -> [FolderItem] {
        var folderItems: [FolderItem] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: [.isDirectoryKey, .fileResourceTypeKey]
            )
            
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
                let imageItems = imageFiles
                    .map { ImageItem(name: $0.lastPathComponent, url: $0) }
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
                let subfolders = scanDirectoryRecursively(
                    at: directory,
                    relativeTo: basePath,
                    debugMessages: &debugMessages
                )
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
