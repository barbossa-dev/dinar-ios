import Foundation
import SwiftData
import Testing
@testable import Dinar

@MainActor
struct LedgerTests {
    let container: ModelContainer
    let context: ModelContext
    let cash: Account
    let card: Account
    let food: LedgerCategory
    let taxi: LedgerCategory
    let salary: LedgerCategory

    init() throws {
        container = try ModelContainer(
            for: Account.self, LedgerCategory.self, LedgerEntry.self, Budget.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        cash = Account(name: "نقدی", kind: .cash, initialBalance: 1_000, colorHex: "000000")
        card = Account(name: "کارت", kind: .bankCard, colorHex: "000000")
        food = LedgerCategory(name: "خوراک", kind: .expense, symbol: "cart", colorHex: "000000", sortOrder: 0)
        taxi = LedgerCategory(name: "تاکسی", kind: .expense, symbol: "car", colorHex: "000000", sortOrder: 1)
        salary = LedgerCategory(name: "حقوق", kind: .income, symbol: "briefcase", colorHex: "000000", sortOrder: 2)
        [cash, card].forEach(context.insert)
        [food, taxi, salary].forEach(context.insert)
    }

    @discardableResult
    private func add(_ kind: EntryKind, _ amount: Int64, _ category: LedgerCategory?, from: Account, to: Account? = nil, date: Date = .now) -> LedgerEntry {
        let entry = LedgerEntry(kind: kind, amount: amount, date: date, category: category, account: from, toAccount: to)
        context.insert(entry)
        return entry
    }

    @Test func balancesIncludeTransfers() throws {
        add(.income, 5_000, salary, from: cash)
        add(.expense, 1_500, food, from: cash)
        add(.transfer, 2_000, nil, from: cash, to: card)
        try context.save()

        #expect(cash.balance == 1_000 + 5_000 - 1_500 - 2_000)
        #expect(card.balance == 2_000)
    }

    @Test func totalsIgnoreTransfers() {
        let rows = [
            add(.expense, 300, food, from: cash),
            add(.income, 1_000, salary, from: cash),
            add(.transfer, 9_000, nil, from: cash, to: card),
        ]
        #expect(Ledger.total(rows, kind: .expense) == 300)
        #expect(Ledger.total(rows, kind: .income) == 1_000)
    }

    @Test func categorySharesAreSortedAndNormalized() {
        let rows = [
            add(.expense, 300, food, from: cash),
            add(.expense, 100, taxi, from: cash),
            add(.expense, 100, food, from: cash),
        ]
        let shares = Ledger.categoryShares(rows, kind: .expense)
        #expect(shares.map(\.category.name) == ["خوراک", "تاکسی"])
        #expect(shares.first?.total == 400)
        #expect(abs((shares.first?.share ?? 0) - 0.8) < 0.0001)
    }

    @Test func monthlyTotalsIncludeEmptyMonths() {
        let now = Date.now
        let twoMonthsAgo = Jalali.adding(months: -2, to: now)
        let rows = [
            add(.expense, 50, food, from: cash, date: twoMonthsAgo),
            add(.expense, 500, food, from: cash, date: now),
        ]
        let months = Ledger.monthlyTotals(rows, endingAt: now, count: 3)
        #expect(months.count == 3)
        #expect(months.map(\.expense) == [50, 0, 500])
    }

    @Test func budgetProgressFlagsOverspending() {
        let budget = Budget(monthlyLimit: 300, category: food)
        context.insert(budget)
        let rows = [add(.expense, 400, food, from: cash)]
        let progress = Ledger.budgetProgress([budget], entries: rows, month: .now)
        #expect(progress.first?.isOver == true)
        #expect(progress.first?.remaining == -100)
    }

    @Test func csvEscapesFields() {
        let entry = add(.expense, 1_200, food, from: cash)
        entry.note = "نان, شیر"
        let csv = Ledger.csv([entry])
        #expect(csv.contains("\"نان, شیر\""))
        #expect(csv.hasPrefix("date,type,amount_rial"))
    }
}
