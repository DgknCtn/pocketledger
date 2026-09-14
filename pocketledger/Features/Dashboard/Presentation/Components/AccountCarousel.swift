import SwiftUI

struct AccountCarousel: View {
    let summaries: [AccountSummary]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(summaries, id: \.account.id) { summary in
                    AccountCard(summary: summary)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AccountCard: View {
    let summary: AccountSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(summary.account.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Text(summary.currentBalance.decimalValue, format: .currency(code: summary.currentBalance.currency.rawValue))
                .font(.body.monospacedDigit())
                .foregroundStyle(summary.currentBalance.isNegative ? .red : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(width: 150, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(summary.account.name), \(summary.currentBalance.decimalValue.formatted(.currency(code: summary.currentBalance.currency.rawValue)))"
        )
    }

    private var iconName: String {
        switch summary.account.kind {
        case .bank: "building.columns"
        case .cash: "banknote"
        case .creditCard: "creditcard"
        }
    }
}
