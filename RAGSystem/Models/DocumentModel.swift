import Foundation
import SwiftData

@Model
final class DocumentModel {
    var id: UUID
    var name: String
    var sourceURL: String
    var content: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var chunks: [ChunkModel] = []

    init(name: String, sourceURL: String, content: String) {
        self.id = UUID()
        self.name = name
        self.sourceURL = sourceURL
        self.content = content
        self.createdAt = Date()
    }

    var isRemote: Bool { sourceURL.hasPrefix("http") }
    var chunkCount: Int { chunks.count }
}
