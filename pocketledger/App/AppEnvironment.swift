import Foundation

/// The runtime environment the app is currently operating under.
///
/// This is a presentation/composition-root concept only: it never leaks into
/// Domain code. `demo` lets the app run against deterministic sample data
/// without touching the production backend; `uiTesting` lets UI tests run
/// against known, network-independent state.
enum AppEnvironment: Sendable {
    case development
    case production
    case demo
    case uiTesting

    /// Resolves the environment for the current process launch.
    static func resolve(
        processInfo: ProcessInfo = .processInfo
    ) -> AppEnvironment {
        if processInfo.arguments.contains("-uiTesting") {
            return .uiTesting
        }

        if processInfo.arguments.contains("-demoMode") {
            return .demo
        }

        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}
