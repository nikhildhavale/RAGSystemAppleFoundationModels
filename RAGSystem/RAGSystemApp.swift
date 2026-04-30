import SwiftUI
import SwiftData

@main
struct RAGSystemApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DocumentModel.self, ChunkModel.self])
    }
}
