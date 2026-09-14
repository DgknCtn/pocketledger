import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel
    var transactionListViewModel: TransactionListViewModel
    var accountListViewModel: AccountListViewModel

    @State private var isPresentingCreateAccountForm = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Dashboard")
                .sheet(isPresented: $isPresentingCreateAccountForm) {
                    AccountFormView(viewModel: accountListViewModel.makeCreateFormViewModel()) { _ in
                        Task {
                            await accountListViewModel.refresh()
                            await viewModel.refresh()
                        }
                    }
                }
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
                ScrollView {
                    VStack(spacing: 20) {
                        if let notice = viewModel.refreshNotice {
                            Text(notice)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        BalanceHeader(totalBalance: snapshot.totalBalance)

                        if snapshot.accountSummaries.isEmpty {
                            EmptyStateView(
                                systemImage: "creditcard",
                                title: "No accounts yet",
                                message: "Create an account to start tracking your money.",
                                actionTitle: "Add Account",
                                action: { isPresentingCreateAccountForm = true }
                            )
                            .frame(height: 220)
                        } else {
                            AccountCarousel(summaries: snapshot.accountSummaries)
                        }

                        MonthlySummaryCard(
                            income: snapshot.monthlyIncome,
                            expense: snapshot.monthlyExpense,
                            previousMonthExpense: snapshot.previousMonthExpense
                        )

                        RecentTransactionsSection(
                            transactions: snapshot.recentTransactions,
                            accounts: snapshot.accountSummaries.map(\.account),
                            transactionListViewModel: transactionListViewModel
                        )
                    }
                    .padding(.vertical)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}
