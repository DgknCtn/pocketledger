import SwiftUI

struct TransactionFormView: View {
    @State var viewModel: TransactionFormViewModel
    var onSaved: (Transaction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $viewModel.kind) {
                        Text("Expense").tag(TransactionKind.expense)
                        Text("Income").tag(TransactionKind.income)
                        Text("Transfer").tag(TransactionKind.transfer)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Account", selection: $viewModel.sourceAccountID) {
                        ForEach(viewModel.accounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }

                    if viewModel.kind == .transfer {
                        Picker("To Account", selection: $viewModel.destinationAccountID) {
                            Text("Choose an account").tag(UUID?.none)
                            ForEach(viewModel.availableDestinationAccounts) { account in
                                Text(account.name).tag(Optional(account.id))
                            }
                        }
                    }

                    if viewModel.kind == .expense {
                        Picker("Category", selection: Binding(
                            get: { viewModel.category ?? .food },
                            set: { viewModel.category = $0 }
                        )) {
                            Text("Food").tag(TransactionCategory.food)
                            Text("Transport").tag(TransactionCategory.transport)
                            Text("Shopping").tag(TransactionCategory.shopping)
                            Text("Bills").tag(TransactionCategory.bills)
                            Text("Entertainment").tag(TransactionCategory.entertainment)
                        }
                    }
                }

                Section {
                    TextField("Amount", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)

                    TextField("Title", text: $viewModel.title)
                        .textInputAutocapitalization(.sentences)

                    TextField("Note (optional)", text: $viewModel.note, axis: .vertical)
                        .lineLimit(2...4)

                    DatePicker("Date", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)

                    if let error = viewModel.fieldError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if case .failed(let message) = viewModel.saveState {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Transaction" : "New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let transaction = await viewModel.save() {
                                onSaved(transaction)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.saveState == .saving || viewModel.accounts.isEmpty)
                }
            }
            .disabled(viewModel.saveState == .saving)
        }
    }
}
