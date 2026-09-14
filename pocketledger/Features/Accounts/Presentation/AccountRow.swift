import SwiftUI

struct AccountRow: View {
    let summary: AccountSummary

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.account.name)
                    .font(.body)
                Text(kindLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(summary.currentBalance.decimalValue, format: .currency(code: summary.currentBalance.currency.rawValue))
                .font(.body.monospacedDigit())
                .foregroundStyle(summary.currentBalance.isNegative ? .red : .primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.account.name), \(kindLabel), balance \(summary.currentBalance.decimalValue.formatted(.currency(code: summary.currentBalance.currency.rawValue)))"
        )
    }

    private var iconName: String {
        switch summary.account.kind {
        case .bank: "building.columns"
        case .cash: "banknote"
        case .creditCard: "creditcard"
        }
    }

    private var kindLabel: String {
        switch summary.account.kind {
        case .bank: "Bank Account"
        case .cash: "Cash"
        case .creditCard: "Credit Card"
        }
    }
}
