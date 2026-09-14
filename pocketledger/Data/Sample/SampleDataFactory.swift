import Foundation

/// Deterministic sample accounts/transactions for the app's demo
/// environment (PRD "Explore with Sample Data"). Never random — the same
/// data every launch, so screenshots and UI tests stay reproducible (see
/// the database specification's sample-dataset guidance: 3-6 months of
/// history, ~40-80 transactions, across all four account kinds).
enum SampleDataFactory {
    static let userID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A0")!
    static let currency = CurrencyCode(rawValue: "TRY")!

    static let mainAccountID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    static let savingsAccountID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    static let creditCardAccountID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
    static let cashAccountID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!

    static func walletProfile() -> WalletProfile {
        WalletProfile(baseCurrency: currency)
    }

    static func accounts(now: Date = Date()) -> [Account] {
        [
            Account(
                id: mainAccountID, name: "Main Account", kind: .bank,
                openingBalance: Money(minorUnits: 2_000_000, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
            ),
            Account(
                id: savingsAccountID, name: "Savings", kind: .bank,
                openingBalance: Money(minorUnits: 5_000_000, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
            ),
            Account(
                id: creditCardAccountID, name: "Credit Card", kind: .creditCard,
                openingBalance: Money(minorUnits: -180_000, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
            ),
            Account(
                id: cashAccountID, name: "Cash", kind: .cash,
                openingBalance: Money(minorUnits: 60_000, currency: currency),
                isArchived: false, archivedAt: nil, createdAt: now, updatedAt: now
            ),
        ]
    }

    /// Four months of transactions (this month back through three months
    /// ago), never future-dated relative to whenever the app actually
    /// runs.
    static func transactions(now: Date = Date()) -> [Transaction] {
        let today = LocalDate.today()
        var results: [Transaction] = []

        for monthsAgo in 0...3 {
            var sequence = 0

            func add(
                day: Int,
                kind: TransactionKind,
                source: UUID,
                destination: UUID? = nil,
                amountMinor: Int64,
                category: TransactionCategory?,
                title: String
            ) {
                let date = Self.date(monthsAgo: monthsAgo, day: day, relativeTo: now)
                guard date <= today else { return }
                sequence += 1
                results.append(
                    Transaction(
                        id: deterministicID(monthsAgo: monthsAgo, sequence: sequence),
                        kind: kind,
                        sourceAccountID: source,
                        destinationAccountID: destination,
                        amount: Money(minorUnits: amountMinor, currency: currency),
                        category: category,
                        title: title,
                        note: nil,
                        date: date,
                        createdAt: now,
                        updatedAt: now
                    )
                )
            }

            let variance = Int64(monthsAgo * 15_000)

            add(day: 1, kind: .income, source: mainAccountID, amountMinor: 4_500_000, category: nil, title: "Salary")

            add(day: 3, kind: .expense, source: mainAccountID, amountMinor: 4_200 + variance, category: .food, title: "Lunch")
            add(day: 7, kind: .expense, source: mainAccountID, amountMinor: 2_800, category: .food, title: "Groceries")
            add(day: 14, kind: .expense, source: creditCardAccountID, amountMinor: 6_500, category: .food, title: "Dinner Out")
            add(day: 22, kind: .expense, source: mainAccountID, amountMinor: 3_100, category: .food, title: "Groceries")

            add(day: 4, kind: .expense, source: cashAccountID, amountMinor: 1_200, category: .transport, title: "Taxi")
            add(day: 11, kind: .expense, source: mainAccountID, amountMinor: 900, category: .transport, title: "Metro Card")
            add(day: 19, kind: .expense, source: cashAccountID, amountMinor: 1_500, category: .transport, title: "Taxi")

            add(day: 9, kind: .expense, source: creditCardAccountID, amountMinor: 8_500 + variance, category: .shopping, title: "Clothing")
            add(day: 17, kind: .expense, source: creditCardAccountID, amountMinor: 2_400, category: .shopping, title: "Home Supplies")

            add(day: 5, kind: .expense, source: mainAccountID, amountMinor: 12_000, category: .bills, title: "Electricity")
            add(day: 6, kind: .expense, source: mainAccountID, amountMinor: 4_500, category: .bills, title: "Internet")

            add(day: 13, kind: .expense, source: mainAccountID, amountMinor: 2_800, category: .entertainment, title: "Cinema")
            add(day: 26, kind: .expense, source: creditCardAccountID, amountMinor: 3_500, category: .entertainment, title: "Concert")

            add(day: 10, kind: .transfer, source: mainAccountID, destination: savingsAccountID, amountMinor: 30_000, category: nil, title: "Move to Savings")
            add(day: 15, kind: .transfer, source: mainAccountID, destination: creditCardAccountID, amountMinor: 15_000, category: nil, title: "Credit Card Payment")
        }

        return results
    }

    private static func date(monthsAgo: Int, day: Int, relativeTo now: Date) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfTargetMonth = calendar.date(byAdding: .month, value: -monthsAgo, to: startOfThisMonth)!
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfTargetMonth)!.count
        let clampedDay = min(day, daysInMonth)
        let targetDate = calendar.date(byAdding: .day, value: clampedDay - 1, to: startOfTargetMonth)!

        let components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        return try! LocalDate(year: components.year!, month: components.month!, day: components.day!)
    }

    /// A stable, collision-free UUID for a given (month, sequence) pair —
    /// distinct from the fixed `...A0`-`...A4` account/profile IDs above.
    private static func deterministicID(monthsAgo: Int, sequence: Int) -> UUID {
        let value = 1_000 + monthsAgo * 100 + sequence
        return UUID(uuidString: String(format: "00000000-0000-0000-0000-%012x", value))!
    }
}
