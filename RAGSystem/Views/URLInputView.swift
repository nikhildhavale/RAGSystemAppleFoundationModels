import SwiftUI

struct URLInputView: View {
    let onSubmit: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""

    private var validURL: URL? {
        guard let url = URL(string: urlString),
              url.scheme == "https" || url.scheme == "http" else { return nil }
        return url
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/file.pdf", text: $urlString)
                        .autocorrectionDisabled()
#if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
#endif
                } header: {
                    Text("Document URL")
                } footer: {
                    Text("Supports PDF and TXT files. The file will be downloaded and processed on-device.")
                }
            }
            .navigationTitle("Import from URL")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if let url = validURL {
                            onSubmit(url)
                            dismiss()
                        }
                    }
                    .disabled(validURL == nil)
                }
            }
        }
    }
}
