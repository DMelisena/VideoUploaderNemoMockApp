import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    let onVideoSelected: (URL) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: PHPickerViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVideoSelected: onVideoSelected)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onVideoSelected: (URL) -> Void

        init(onVideoSelected: @escaping (URL) -> Void) {
            self.onVideoSelected = onVideoSelected
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            // Handle video files
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    if let error = error {
                        print("Error loading video: \(error)")
                        return
                    }

                    guard let url = url else {
                        print("No URL provided for video")
                        return
                    }

                    // Create a permanent copy immediately
                    self?.createPermanentCopy(from: url) { permanentURL in
                        DispatchQueue.main.async {
                            if let permanentURL = permanentURL {
                                self?.onVideoSelected(permanentURL)
                            } else {
                                print("Failed to create permanent copy of video")
                            }
                        }
                    }
                }
            }
        }

        private func createPermanentCopy(from temporaryURL: URL, completion: @escaping (URL?) -> Void) {
            // Get file info
            let originalFileName = temporaryURL.lastPathComponent
            let fileExtension = temporaryURL.pathExtension
            let nameWithoutExtension = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")

            // Create unique filename
            let timestamp = Int(Date().timeIntervalSince1970)
            let uniqueFileName = "\(nameWithoutExtension)_\(timestamp).\(fileExtension)"
            let permanentURL = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueFileName)

            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: permanentURL.path) {
                    try FileManager.default.removeItem(at: permanentURL)
                }

                // Copy the file to permanent location
                try FileManager.default.copyItem(at: temporaryURL, to: permanentURL)

                // Verify the file exists at the permanent location
                guard FileManager.default.fileExists(atPath: permanentURL.path) else {
                    print("Failed to verify copied file at: \(permanentURL.path)")
                    completion(nil)
                    return
                }

                print("Successfully copied video to: \(permanentURL.path)")
                completion(permanentURL)

            } catch {
                print("Error copying video file: \(error)")
                completion(nil)
            }
        }
    }
}
