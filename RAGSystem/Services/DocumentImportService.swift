import Foundation
import PDFKit

final class DocumentImportService {

    enum ImportError: LocalizedError {
        case unsupportedFormat
        case downloadFailed(Int)
        case extractionFailed
        case emptyContent

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "Unsupported format. Use PDF or TXT files."
            case .downloadFailed(let code): return "Download failed (HTTP \(code))."
            case .extractionFailed: return "Could not extract text from the file."
            case .emptyContent: return "The document appears to be empty."
            }
        }
    }

    func importDocument(from url: URL) async throws -> (name: String, content: String, sourceURL: String) {
        if url.isFileURL {
            return try importLocalFile(url: url)
        } else {
            return try await downloadAndImport(url: url)
        }
    }

    private func importLocalFile(url: URL) throws -> (name: String, content: String, sourceURL: String) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()
        let name = url.deletingPathExtension().lastPathComponent

        let content = try extractText(from: url, ext: ext)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyContent
        }
        return (name: name, content: content, sourceURL: url.absoluteString)
    }

    private func downloadAndImport(url: URL) async throws -> (name: String, content: String, sourceURL: String) {
        let (localURL, response) = try await URLSession.shared.download(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ImportError.downloadFailed(http.statusCode)
        }

        let mime = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        let urlExt = url.pathExtension.lowercased()
        let ext = urlExt.isEmpty ? (mime.contains("pdf") ? "pdf" : "txt") : urlExt
        let name = url.deletingPathExtension().lastPathComponent.isEmpty
            ? "Downloaded Document"
            : url.deletingPathExtension().lastPathComponent

        let content = try extractText(from: localURL, ext: ext)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.emptyContent
        }
        return (name: name, content: content, sourceURL: url.absoluteString)
    }

    private func extractText(from url: URL, ext: String) throws -> String {
        switch ext {
        case "pdf":
            return try extractPDF(url: url)
        case "txt", "md", "text", "rtf":
            return try String(contentsOf: url, encoding: .utf8)
        default:
            if let t = try? String(contentsOf: url, encoding: .utf8), !t.isEmpty { return t }
            return try extractPDF(url: url)
        }
    }

    private func extractPDF(url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else { throw ImportError.extractionFailed }
        var text = ""
        for i in 0..<pdf.pageCount {
            text += (pdf.page(at: i)?.string ?? "") + "\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
