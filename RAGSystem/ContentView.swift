import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var rag = RAGService()

    var body: some View {
        TabView {
            Tab("Documents", systemImage: "doc.fill") {
                DocumentsView()
            }
            Tab("Chat", systemImage: "message.fill") {
                ChatView()
            }
        }
        .environment(rag)
        .onAppear { rag.configure(with: modelContext) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DocumentModel.self, ChunkModel.self], inMemory: true)
}
