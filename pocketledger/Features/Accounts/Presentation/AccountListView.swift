import SwiftUI

struct AccountListView: View {
    var viewModel: AccountListViewModel

    @State private var isPresentingCreateForm = false
    @State private var editingAccount: Account?
    @State private var pendingDeleteAccount: Account?
    @State private var actionErrorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Accounts")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            isPresentingCreateForm = true
                        } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $isPresentingCreateForm) {
                    AccountFormView(viewModel: viewModel.makeCreateFormViewModel()) { _ in
                        Task { await viewModel.refresh() }
                    }
                }
                .sheet(item: $editingAccount) { account in
                    AccountFormView(viewModel: viewModel.makeEditFormViewModel(for: account)) { _ in
                        Task { await viewModel.refresh() }
                    }
                }
                .confirmationDialog(
                    "Delete this account?",
                    isPresented: Binding(
                        get: { pendingDeleteAccount != nil },
                        set: { isPresented in if !isPresented { pendingDeleteAccount = nil } }
                    ),
                    presenting: pendingDeleteAccount
                ) { account in
                    Button("Delete", role: .destructive) {
                        Task {
                            if let message = await viewModel.delete(account) {
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView("Loading accounts…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }

        case .loaded:
            if viewModel.summaries.isEmpty {
                EmptyStateView(
                    systemImage: "creditcard",
                    title: "No accounts yet",
                    message: "Create an account to start tracking your money.",
                    actionTitle: "Add Account"
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

                    ForEach(viewModel.summaries, id: \.account.id) { summary in
                        AccountRow(summary: summary)
                            .contentShape(Rectangle())
                            .onTapGesture { editingAccount = summary.account }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    pendingDeleteAccount = summary.account
                                }

                                Button("Archive") {
                                    Task {
                                        if let message = await viewModel.archive(summary.account) {
                                            actionErrorMessage = message
                                        }
                                    }
                                }
                                .tint(.orange)
                            }
                    }
                }
                .listStyle(.plain)
                .refreshable { await viewModel.refresh() }
            }
        }
    }
}
