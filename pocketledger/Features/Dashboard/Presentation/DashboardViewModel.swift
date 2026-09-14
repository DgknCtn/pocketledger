import Foundation

enum DashboardPhase: Equatable {
    case loading
    case loaded
    case failed(String)
}

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var snapshot: DashboardSnapshot?
    private(set) var phase: DashboardPhase = .loading
    private(set) var refreshNotice: String?

    private let loadDashboardUseCase: LoadDashboardUseCase
    private var hasLoadedOnce = false

    init(loadDashboardUseCase: LoadDashboardUseCase) {
        self.loadDashboardUseCase = loadDashboardUseCase
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await load()
    }

    func load() async {
        phase = .loading

        if let cached = try? await loadDashboardUseCase.loadCached() {
            snapshot = cached
            phase = .loaded
        }

        await refresh()
        hasLoadedOnce = true
    }

    func refresh() async {
        do {
            snapshot = try await loadDashboardUseCase.refresh()
            phase = .loaded
            refreshNotice = nil
        } catch {
            if phase == .loaded {
                refreshNotice = PresentationErrorMapper.message(for: error)
            } else {
                phase = .failed(PresentationErrorMapper.message(for: error))
            }
        }
    }
}
