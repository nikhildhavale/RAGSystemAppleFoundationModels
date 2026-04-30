import Foundation
import NaturalLanguage

final class EmbeddingService {
    static let shared = EmbeddingService()

    private let sentenceEmbedding: NLEmbedding?

    private init() {
        sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var isAvailable: Bool { sentenceEmbedding != nil }

    func embed(_ text: String) -> [Float]? {
        guard let emb = sentenceEmbedding,
              let vector = emb.vector(for: text) else { return nil }
        return vector.map(Float.init)
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let magA = a.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        let magB = b.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (magA * magB)
    }

    // Fallback: TF-IDF-inspired keyword overlap score when embeddings unavailable
    func keywordScore(query: String, text: String) -> Float {
        let qWords = tokenize(query)
        guard !qWords.isEmpty else { return 0 }
        let tWords = tokenize(text)
        let tSet = Dictionary(tWords.map { ($0, 1) }, uniquingKeysWith: +)
        let hits = qWords.reduce(0) { $0 + (tSet[$1] ?? 0) }
        return Float(hits) / Float(qWords.count)
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .init(charactersIn: " \t\n.,!?;:\"'()-"))
            .filter { $0.count > 2 }
    }
}
