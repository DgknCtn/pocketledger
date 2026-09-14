import Charts
import SwiftUI

struct MonthlySpendingChart: View {
    let points: [MonthlySpendingPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Spending")
                .font(.headline)

            Chart(points) { point in
                BarMark(
                    x: .value("Month", point.month.shortLabel),
                    y: .value("Expense", point.expense.decimalValue)
                )
                .foregroundStyle(.blue)
            }
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
        guard let currency = points.first?.expense.currency.rawValue else {
            return "Monthly spending. No data."
        }
        let parts = points.map { point in
            "\(point.month.shortLabel): \(point.expense.decimalValue.formatted(.currency(code: currency)))"
        }
        return "Monthly spending. " + parts.joined(separator: ". ")
    }
}
