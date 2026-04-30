import Foundation
import SwiftData
import FoundationModels

@Observable
@MainActor
final class RAGService {
    var documents: [DocumentModel] = []
    var isProcessing = false
    var processingStatus = ""

    private let importer = DocumentImportService()
    private let embedder = EmbeddingService.shared
    private let chunker = ChunkingService.shared
    private var context: ModelContext?

    func configure(with context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        guard let context else { return }
        let descriptor = FetchDescriptor<DocumentModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        documents = (try? context.fetch(descriptor)) ?? []
    }

    func addDocument(from url: URL) async throws {
        isProcessing = true
        processingStatus = "Importing…"
        defer { isProcessing = false; processingStatus = "" }

        let (name, content, sourceURL) = try await importer.importDocument(from: url)

        processingStatus = "Chunking text…"
        let chunkTexts = chunker.chunk(content)

        let doc = DocumentModel(name: name, sourceURL: sourceURL, content: content)

        processingStatus = "Generating embeddings… (0/\(chunkTexts.count))"
        for (i, text) in chunkTexts.enumerated() {
            let emb = embedder.embed(text) ?? []
            let chunk = ChunkModel(text: text, chunkIndex: i, embedding: emb)
            chunk.document = doc
            doc.chunks.append(chunk)
            if i % 5 == 0 {
                processingStatus = "Generating embeddings… (\(i)/\(chunkTexts.count))"
            }
        }

        guard let context else { return }
        context.insert(doc)
        try context.save()
        reload()
    }

    func deleteDocument(_ doc: DocumentModel) throws {
        guard let context else { return }
        context.delete(doc)
        try context.save()
        reload()
    }

    func findRelevantChunks(for query: String, in doc: DocumentModel? = nil, topK: Int = 5) -> [ChunkModel] {
        let pool = doc != nil ? doc!.chunks : documents.flatMap(\.chunks)
        guard !pool.isEmpty else { return [] }

        let queryEmbedding = embedder.embed(query)

        let scored: [(ChunkModel, Float)] = pool.map { chunk in
            let semScore: Float
            if let qe = queryEmbedding, !chunk.embedding.isEmpty {
                semScore = embedder.cosineSimilarity(qe, chunk.embedding)
            } else {
                semScore = 0
            }
            let kwScore = embedder.keywordScore(query: query, text: chunk.text)
            return (chunk, semScore * 0.7 + kwScore * 0.3)
        }

        return scored.sorted { $0.1 > $1.1 }.prefix(topK).map(\.0)
    }

    // Returns an AsyncThrowingStream that yields the accumulated response text as it streams.
    nonisolated func generateAnswer(
        question: String,
        documentFilter: DocumentModel? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task { @MainActor in
                let chunks = self.findRelevantChunks(for: question, in: documentFilter)

                guard !chunks.isEmpty else {
                    continuation.yield("No relevant content found. Please add some documents first.")
                    continuation.finish()
                    return
                }

                let contextBlock = chunks.enumerated().map { i, c in
                    "[\(i + 1)] \(c.text)"
                }.joined(separator: "\n\n")

                let prompt = """
                Answer the question below using ONLY the provided context. \
                If the context does not contain the answer, say so clearly.

                Context:
                \(contextBlock)

                Question: \(question)
                """

                do {
                    let session = LanguageModelSession(
                        instructions: "You are a precise document assistant. Answer strictly from the context given. Cite chunk numbers like [1] when relevant."
                    )

                    for try await partial in session.streamResponse(to: prompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
