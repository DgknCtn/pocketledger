import SwiftUI

struct TransactionListView: View {
    @Bindable var viewModel: TransactionListViewModel

    @State private var isPresentingCreateForm = false
    @State private var editingTransaction: Transaction?
    @State private var pendingDeleteTransaction: Transaction?
    @State private var actionErrorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Transactions")
                .searchable(text: $viewModel.searchText, prompt: "Search by title")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPresentingCreateForm = true
                        } label: {
                            Label("Add Transaction", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        filterMenu
                    }
                }
                .sheet(isPresented: $isPresentingCreateForm) {
                    TransactionFormView(viewModel: viewModel.makeCreateFormViewModel()) { _ in
                        Task { await viewModel.refresh() }
                    }
                }
                .sheet(item: $editingTransaction) { transaction in
                    TransactionFormView(viewModel: viewModel.makeEditFormViewModel(for: transaction)) { _ in
                        Task { await viewModel.refresh() }
                    }
                }
                .confirmationDialog(
                    "Delete this transaction?",
                    isPresented: Binding(
                        get: { pendingDeleteTransaction != nil },
                        set: { isPresented in if !isPresented { pendingDeleteTransaction = nil } }
                    ),
                    presenting: pendingDeleteTransaction
                ) { transaction in
                    Button("Delete", role: .destructive) {
                        Task {
                            if let message = await viewModel.delete(transaction) {
                                actionErrorMessage = message
                            }
                        }
                    }
                } message: { _ in
                    Text("This can't be undone.")
                }
                .alert(
                    "Couldn't complete that action",
                    isPresented: Binding(
                        get: { actionErrorMessage != nil },
                        set: { isPresented in if !isPresented { actionErrorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(actionErrorMessage ?? "")
                }
        }
        .task { await viewModel.loadIfNeeded() }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Type", selection: Binding(
                get: { viewModel.kindFilter },
                set: { viewModel.kindFilter = $0 }
            )) {
                Text("All Types").tag(TransactionKind?.none)
                Text("Income").tag(TransactionKind?.some(.income))
                Text("Expense").tag(TransactionKind?.some(.expense))
                Text("Transfer").tag(TransactionKind?.some(.transfer))
            }

            Picker("Category", selection: Binding(
                get: { viewModel.categoryFilter },
                set: { viewModel.categoryFilter = $0 }
            )) {
                Text("All Categories").tag(TransactionCategory?.none)
                Text("Food").tag(TransactionCategory?.some(.food))
                Text("Transport").tag(TransactionCategory?.some(.transport))
                Text("Shopping").tag(TransactionCategory?.some(.shopping))
                Text("Bills").tag(TransactionCategory?.some(.bills))
                Text("Entertainment").tag(TransactionCategory?.some(.entertainment))
            }

            if viewModel.hasActiveFilters {
                Button("Clear Filters", role: .destructive) { viewModel.clearFilters() }
            }
        } label: {
            Label(
                "Filter",
                systemImage: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView("Loading transactions…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }

        case .loaded:
            if viewModel.filteredTransactions.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: viewModel.hasActiveFilters || !viewModel.searchText.isEmpty
                        ? "No matching transactions"
                        : "No transactions yet",
                    message: viewModel.hasActiveFilters || !viewModel.searchText.isEmpty
                        ? "Try a different search or filter."
                        : "Add your first transaction to start tracking your spending.",
                    actionTitle: viewModel.hasActiveFilters || !viewModel.searchText.isEmpty ? nil : "Add Transaction"
                ) {
                    isPresentingCreateForm = true
                }
            } else {
                List {
                    if let notice = viewModel.refreshNotice {
                        Text(notice)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.filteredTransactions, id: \.id) { transaction in
                        TransactionRow(
                            transaction: transaction,
                            sourceAccountName: viewModel.accountName(for: transaction.sourceAccountID),
                            destinationAccountName: transaction.destinationAccountID.map(viewModel.accountName(for:))
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = transaction }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                pendingDeleteTransaction = transaction
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}
