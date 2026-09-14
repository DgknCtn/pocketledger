import Charts
import SwiftUI

struct IncomeExpenseChart: View {
    let points: [IncomeExpensePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Income vs Expense")
                .font(.headline)

            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Month", point.month.shortLabel),
                        y: .value("Amount", point.income.decimalValue)
                    )
                    .foregroundStyle(by: .value("Series", "Income"))
                    .symbol(by: .value("Series", "Income"))

                    LineMark(
                        x: .value("Month", point.month.shortLabel),
                        y: .value("Amount", point.expense.decimalValue)
                    )
                    .foregroundStyle(by: .value("Series", "Expense"))
                    .symbol(by: .value("Series", "Expense"))
                }
            }
            .chartForegroundStyleScale([
                "Income": Color.green,
                "Expense": Color.red,
            ])
            .frame(height: 180)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let currency = points.first?.income.currency.rawValue else {
            return "Income versus expense. No data."
        }
        let parts = points.map { point in
            "\(point.month.shortLabel): income \(point.income.decimalValue.formatted(.currency(code: currency))), expense \(point.expense.decimalValue.formatted(.currency(code: currency)))"
        }
        return "Income versus expense. " + parts.joined(separator: ". ")
    }
}
