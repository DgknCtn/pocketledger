import SwiftUI

/// Covers financial content while the app is inactive/backgrounded, so the
/// app switcher snapshot never shows account balances or transactions (see
/// the PRD's "Background Protection" requirement).
struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
        .transition(.opacity)
    }
}

#Preview {
    PrivacyShieldView()
}
