import SwiftUI

struct DownloadedFilesView: View {
    @Binding var showDownloadedFiles: Bool
    @StateObject private var viewModel = DownloadedFilesViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("Back") {
                        showDownloadedFiles = false
                    }
                    .padding()
                    
                    Spacer()
                    
                    Text("Downloaded Files")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Empty space for symmetry
                    Button("") {}
                        .disabled(true)
                        .opacity(0)
                        .padding()
                }
                
                if viewModel.downloadedFolders.isEmpty {
                    Spacer()
                    Text("No downloaded files yet")
                        .foregroundColor(.gray)
                        .font(.body)
                    Spacer()
                } else {
                    List(viewModel.downloadedFolders, id: \.self) { folderURL in
                        NavigationLink(
                            destination: DownloadedGalleryView(
                                rootURL: folderURL,
                                viewModel: viewModel
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folderURL.lastPathComponent)
                                    .font(.headline)
                                Text("Tap to view images")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            viewModel.loadDownloadedFolders()
        }
    }
}

#Preview {
    DownloadedFilesView(showDownloadedFiles: .constant(true))
}
