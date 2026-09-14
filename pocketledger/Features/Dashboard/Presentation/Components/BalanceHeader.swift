import SwiftUI

struct BalanceHeader: View {
    let totalBalance: Money

    var body: some View {
        VStack(spacing: 4) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalBalance.decimalValue, format: .currency(code: totalBalance.currency.rawValue))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(totalBalance.isNegative ? .red : .primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Total balance \(totalBalance.decimalValue.formatted(.currency(code: totalBalance.currency.rawValue)))"
        )
    }
}
