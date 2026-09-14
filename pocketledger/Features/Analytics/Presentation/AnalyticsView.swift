import SwiftUI

struct AnalyticsView: View {
    var viewModel: AnalyticsViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Analytics")
        }
        .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }

        case .loaded:
            if let snapshot = viewModel.snapshot {
                if snapshot.categoryDistribution.isEmpty && snapshot.monthlySpending.allSatisfy({ $0.expense.isZero }) {
                    EmptyStateView(
                        systemImage: "chart.pie",
                        title: "No analytics yet",
                        message: "Analytics will appear after you add transactions."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            if let notice = viewModel.refreshNotice {
                                Text(notice)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            MonthlySpendingChart(points: snapshot.monthlySpending)
                            CategoryDistributionChart(items: snapshot.categoryDistribution)
                            IncomeExpenseChart(points: snapshot.incomeExpenseTrend)
                        }
                        .padding(.vertical)
                    }
                    .refreshable { await viewModel.refresh() }
                }
            }
        }
    }
}
