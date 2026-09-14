import Charts
import SwiftUI

/// Pairs the pie chart with a always-visible legend list of
/// category/amount/percentage rows — the PRD explicitly forbids conveying
/// this information through color alone, so the numbers are never hidden
/// behind a VoiceOver-only description the way the other two charts do.
struct CategoryDistributionChart: View {
    let items: [CategorySpending]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Distribution")
                .font(.headline)

            if items.isEmpty {
                Text("No expenses this month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(items) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount.decimalValue),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Category", categoryLabel(item.category)))
                    .accessibilityHidden(true)
                }
                .frame(height: 180)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items) { item in
                        HStack {
                            Text(categoryLabel(item.category))
                            Spacer()
                            Text(item.amount.decimalValue, format: .currency(code: item.amount.currency.rawValue))
                                .foregroundStyle(.secondary)
                            if let percentage = item.percentage {
                                Text("\(percentage)%")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: item))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func categoryLabel(_ category: TransactionCategory) -> String {
        switch category {
        case .food: "Food"
        case .transport: "Transport"
        case .shopping: "Shopping"
        case .bills: "Bills"
        case .entertainment: "Entertainment"
        }
    }

    private func accessibilityLabel(for item: CategorySpending) -> String {
        let amountText = item.amount.decimalValue.formatted(.currency(code: item.amount.currency.rawValue))
        if let percentage = item.percentage {
            return "\(categoryLabel(item.category)), \(percentage) percent, \(amountText)."
        }
        return "\(categoryLabel(item.category)), \(amountText)."
    }
}
