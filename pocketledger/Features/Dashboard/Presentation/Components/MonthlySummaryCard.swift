import Foundation
import SwiftUI

struct MonthlySummaryCard: View {
    let income: Money
    let expense: Money
    let previousMonthExpense: Money?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(income.decimalValue, format: .currency(code: income.currency.rawValue))
                        .foregroundStyle(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expense.decimalValue, format: .currency(code: expense.currency.rawValue))
                }
            }

            if let comparisonText {
                Text(comparisonText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    /// `nil` whenever there's no meaningful prior-month baseline to compare
    /// against — never shows a misleading 0%/∞% change (see the PRD's
    /// insight-quality rules, which apply here too).
    private var comparisonText: String? {
        guard let previousMonthExpense else { return nil }
        guard let roundedPercent = PercentageChange.compute(current: expense, previous: previousMonthExpense) else {
            return nil
        }

        guard roundedPercent != 0 else { return "Same as last month" }
        let arrow = roundedPercent > 0 ? "↑" : "↓"
        return "\(arrow) \(abs(roundedPercent))% vs last month"
    }
}
