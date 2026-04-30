import SwiftUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(RAGService.self) private var rag
    @State private var showAddSheet = false
    @State private var showFilePicker = false
    @State private var showURLInput = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if rag.documents.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(rag.isProcessing)
                }
            }
            .confirmationDialog("Add Document", isPresented: $showAddSheet) {
                Button("Choose File (PDF / TXT)") { showFilePicker = true }
                Button("From URL") { showURLInput = true }
                Button("Cancel", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    runImport(url)
                }
            }
            .sheet(isPresented: $showURLInput) {
                URLInputView { url in runImport(url) }
            }
            .alert("Import Failed", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay { if rag.isProcessing { processingOverlay } }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Add a PDF, TXT file, or paste a URL to get started.")
        } actions: {
            Button("Add Document") { showAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            ForEach(rag.documents) { doc in
                DocumentRow(doc: doc)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            try? rag.deleteDocument(doc)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.4)
                Text(rag.processingStatus)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func runImport(_ url: URL) {
        Task {
            do {
                try await rag.addDocument(from: url)
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct DocumentRow: View {
    let doc: DocumentModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: doc.isRemote ? "link.circle.fill" : "doc.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(doc.chunkCount) chunks")
                    Text("·")
                    Text(doc.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
