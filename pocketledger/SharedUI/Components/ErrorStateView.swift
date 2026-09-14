import SwiftUI

/// A full-screen, blocking error state (no content available at all) with
/// a retry action — see the PRD's "Recoverable Error" requirement. Never
/// shows a raw technical message; `message` must already be user-facing
/// copy (see `PresentationErrorMapper`).
struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorStateView(message: "You appear to be offline. Showing your most recent saved data.") {}
}
