import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    let sourceAccountName: String
    let destinationAccountName: String?

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(signedAmount, format: .currency(code: transaction.amount.currency.rawValue))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(amountColor)
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch transaction.kind {
        case .income: "arrow.down.circle"
        case .expense: categoryIconName
        case .transfer: "arrow.left.arrow.right.circle"
        }
    }

    private var categoryIconName: String {
        switch transaction.category {
        case .food: "fork.knife"
        case .transport: "car"
        case .shopping: "bag"
        case .bills: "doc.text"
        case .entertainment: "film"
        case nil: "circle"
        }
    }

    private var iconColor: Color {
        switch transaction.kind {
        case .income: .green
        case .expense: .primary
        case .transfer: .blue
        }
    }

    private var subtitle: String {
        switch transaction.kind {
        case .income:
            sourceAccountName
        case .expense:
            "\(categoryLabel) · \(sourceAccountName)"
        case .transfer:
            "\(sourceAccountName) → \(destinationAccountName ?? "")"
        }
    }

    private var categoryLabel: String {
        switch transaction.category {
        case .food: "Food"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .bills: "Bills"
        case .entertainment: "Entertainment"
        case nil: ""
        }
    }

    private var signedAmount: Decimal {
        transaction.kind == .expense ? -transaction.amount.decimalValue : transaction.amount.decimalValue
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .income: .green
        case .expense: .primary
        case .transfer: .secondary
        }
    }

    private var formattedDate: String {
        "\(transaction.date.year)-\(String(format: "%02d", transaction.date.month))-\(String(format: "%02d", transaction.date.day))"
    }

    private var accessibilityLabel: String {
        let kindLabel = switch transaction.kind {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        }
        let amountText = signedAmount.formatted(.currency(code: transaction.amount.currency.rawValue))
        return "\(kindLabel). \(transaction.title). \(subtitle). \(amountText). \(formattedDate)."
    }
}
