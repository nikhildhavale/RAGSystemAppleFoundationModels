import Foundation
import NaturalLanguage

final class ChunkingService {
    static let shared = ChunkingService()

    private let targetChunkChars = 800
    private let overlapSentences = 2

    private init() {}

    func chunk(_ text: String) -> [String] {
        let sentences = tokenizeSentences(text)
        guard !sentences.isEmpty else { return [] }

        var chunks: [String] = []
        var buffer: [String] = []
        var bufferLen = 0

        for sentence in sentences {
            buffer.append(sentence)
            bufferLen += sentence.count

            if bufferLen >= targetChunkChars {
                chunks.append(buffer.joined(separator: " "))
                let overlap = buffer.suffix(overlapSentences)
                buffer = Array(overlap)
                bufferLen = overlap.reduce(0) { $0 + $1.count }
            }
        }

        if !buffer.isEmpty {
            chunks.append(buffer.joined(separator: " "))
        }

        return chunks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func tokenizeSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { sentences.append(s) }
            return true
        }
        return sentences
    }
}
