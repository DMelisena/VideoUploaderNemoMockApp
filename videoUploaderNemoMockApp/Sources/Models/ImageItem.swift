import Foundation

struct ImageItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}
