import SwiftUI

struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    /// Looked up from the Dashboard's own `DashboardSnapshot.accountSummaries`
    /// rather than `transactionListViewModel.accountName(for:)` — the
    /// Transactions tab's ViewModel may not have loaded yet if Dashboard is
    /// the first tab shown, which would otherwise show "Unknown Account"
    /// for every row.
    let accounts: [Account]
    var transactionListViewModel: TransactionListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                if !transactions.isEmpty {
                    NavigationLink("See All") {
                        TransactionListView(viewModel: transactionListViewModel)
                    }
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)

            if transactions.isEmpty {
                Text("No transactions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(transactions, id: \.id) { transaction in
                        TransactionRow(
                            transaction: transaction,
                            sourceAccountName: accountName(for: transaction.sourceAccountID),
                            destinationAccountName: transaction.destinationAccountID.map(accountName(for:))
                        )
                        .padding(.horizontal)

                        if transaction.id != transactions.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }
    }

    private func accountName(for id: UUID) -> String {
        accounts.first(where: { $0.id == id })?.name ?? "Unknown Account"
    }
}
