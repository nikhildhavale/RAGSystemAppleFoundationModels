import Foundation
import SwiftData

@Model
final class ChunkModel {
    var id: UUID
    var text: String
    var chunkIndex: Int
    var embeddingData: Data
    var document: DocumentModel?

    init(text: String, chunkIndex: Int, embedding: [Float] = []) {
        self.id = UUID()
        self.text = text
        self.chunkIndex = chunkIndex
        self.embeddingData = Self.pack(embedding)
    }

    var embedding: [Float] {
        get { Self.unpack(embeddingData) }
        set { embeddingData = Self.pack(newValue) }
    }

    private static func pack(_ v: [Float]) -> Data {
        v.withUnsafeBytes { Data($0) }
    }

    private static func unpack(_ d: Data) -> [Float] {
        let count = d.count / MemoryLayout<Float>.stride
        guard count > 0 else { return [] }
        return d.withUnsafeBytes { Array($0.bindMemory(to: Float.self).prefix(count)) }
    }
}
