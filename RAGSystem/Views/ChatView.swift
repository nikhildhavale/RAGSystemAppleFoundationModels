import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    var isStreaming = false

    enum Role { case user, assistant }
}

struct ChatView: View {
    @Environment(RAGService.self) private var rag
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isGenerating = false
    @State private var selectedDoc: DocumentModel?
    @State private var errorText: String?
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if rag.documents.count > 1 {
                    docFilterBar
                }
                messageScroll
                inputBar
            }
            .navigationTitle("Chat")
            .alert("Error", isPresented: .constant(errorText != nil)) {
                Button("OK") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    // MARK: - Subviews

    private var docFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All Documents", selected: selectedDoc == nil) {
                    selectedDoc = nil
                }
                ForEach(rag.documents) { doc in
                    FilterChip(label: doc.name, selected: selectedDoc?.id == doc.id) {
                        selectedDoc = doc
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.groupedBackground)
    }

    private var messageScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if messages.isEmpty { placeholder }
                    ForEach(messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 52))
                .foregroundStyle(.blue)
                .padding(.top, 80)
            Text("Ask your documents anything")
                .font(.title3).fontWeight(.semibold)
            Text(rag.documents.isEmpty
                 ? "Add documents in the Documents tab first."
                 : "Ask a question about your \(rag.documents.count == 1 ? "document" : "\(rag.documents.count) documents").")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask a question…", text: $input, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.secondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .disabled(isGenerating)

            Button {
                if isGenerating { cancelGeneration() } else { send() }
            } label: {
                Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(isGenerating ? .red : (canSend ? .blue : .gray))
            }
            .disabled(!canSend && !isGenerating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.groupedBackground)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isGenerating
        && !rag.documents.isEmpty
    }

    // MARK: - Actions

    private func send() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""

        messages.append(ChatMessage(role: .user, text: question))
        let aiMsg = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(aiMsg)
        let aiID = aiMsg.id
        isGenerating = true

        streamTask = Task {
            let stream = rag.generateAnswer(question: question, documentFilter: selectedDoc)
            do {
                for try await partial in stream {
                    if Task.isCancelled { break }
                    update(id: aiID, text: partial)
                }
            } catch {
                update(id: aiID, text: "⚠️ \(error.localizedDescription)")
            }
            finalize(id: aiID)
        }
    }

    private func cancelGeneration() {
        streamTask?.cancel()
        streamTask = nil
        if let idx = messages.indices.last {
            messages[idx].isStreaming = false
            if messages[idx].text.isEmpty { messages[idx].text = "_(cancelled)_" }
        }
        isGenerating = false
    }

    private func update(id: UUID, text: String) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = text
    }

    private func finalize(id: UUID) {
        guard let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].isStreaming = false
        isGenerating = false
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 50) }

            if message.isStreaming && message.text.isEmpty {
                TypingIndicator()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.secondaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(message.text.isEmpty ? " " : message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color.secondaryGroupedBackground)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            if message.role == .assistant { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Typing dots

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(selected ? .semibold : .regular)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? Color.blue : Color.secondaryGroupedBackground)
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
