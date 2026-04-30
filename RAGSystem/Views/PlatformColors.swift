import SwiftUI

extension Color {
    static var groupedBackground: Color {
#if os(iOS) || os(visionOS)
        Color(uiColor: .systemGroupedBackground)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }

    static var secondaryGroupedBackground: Color {
#if os(iOS) || os(visionOS)
        Color(uiColor: .secondarySystemGroupedBackground)
#else
        Color(nsColor: .controlBackgroundColor)
#endif
    }
}
