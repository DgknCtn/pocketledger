import SwiftUI

struct AccountFormView: View {
    @State var viewModel: AccountFormViewModel
    var onSaved: (Account) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Account Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Account name")

                    if viewModel.isKindEditable {
                        Picker("Type", selection: $viewModel.kind) {
                            Text("Bank Account").tag(AccountKind.bank)
                            Text("Cash").tag(AccountKind.cash)
                            Text("Credit Card").tag(AccountKind.creditCard)
                        }
                    }
                }

                Section {
                    TextField(viewModel.amountFieldTitle, text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(viewModel.amountFieldTitle)

                    if let error = viewModel.amountFieldError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text(viewModel.amountFieldTitle)
                }

                if case .failed(let message) = viewModel.saveState {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Account" : "New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if let account = await viewModel.save() {
                                onSaved(account)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.saveState == .saving)
                }
            }
            .disabled(viewModel.saveState == .saving)
        }
    }
}
