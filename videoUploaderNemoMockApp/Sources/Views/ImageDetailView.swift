import SwiftUI

struct ImageDetailView: View {
    let image: ImageItem
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            AsyncImage(url: image.url) { loadedImage in
                loadedImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .navigationTitle(image.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ImageDetailView(
        image: ImageItem(
            name: "sample.jpg",
            url: URL(fileURLWithPath: "/tmp/sample.jpg")
        ),
        onDismiss: {}
    )
}
