import Foundation
import SwiftData

struct CategoryShare: Identifiable {
    let category: LedgerCategory
    let total: Int64
    let share: Double

    var id: PersistentIdentifier { category.persistentModelID }
}

struct MonthlyTotal: Identifiable {
    let monthStart: Date
    let income: Int64
    let expense: Int64

    var id: Date { monthStart }
    var net: Int64 { income - expense }
}

struct BudgetProgress: Identifiable {
    let budget: Budget
    let category: LedgerCategory
    let spent: Int64

    var id: PersistentIdentifier { budget.persistentModelID }
    var limit: Int64 { budget.monthlyLimit }
    var remaining: Int64 { limit - spent }
    var fraction: Double { limit > 0 ? Double(spent) / Double(limit) : 0 }
    var isOver: Bool { spent > limit }
    var isNearLimit: Bool { !isOver && fraction >= 0.8 }
}

/// Pure functions over ledger entries. Views fetch with `@Query` and call these,
/// which keeps business rules in one tested place.
enum Ledger {

    static func total(_ entries: [LedgerEntry], kind: EntryKind) -> Int64 {
        entries.lazy.filter { $0.kind == kind }.reduce(0) { $0 + $1.amount }
    }

    static func entries(_ entries: [LedgerEntry], in interval: DateInterval) -> [LedgerEntry] {
        entries.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    /// Category totals for one kind, largest first. Uncategorized entries are skipped.
    static func categoryShares(_ entries: [LedgerEntry], kind: EntryKind) -> [CategoryShare] {
        var totals: [ObjectIdentifier: (LedgerCategory, Int64)] = [:]
        for entry in entries where entry.kind == kind {
            guard let category = entry.category else { continue }
            let key = ObjectIdentifier(category)
            totals[key, default: (category, 0)].1 += entry.amount
        }
        let grand = totals.values.reduce(Int64(0)) { $0 + $1.1 }
        guard grand > 0 else { return [] }
        return totals.values
            .map { CategoryShare(category: $0.0, total: $0.1, share: Double($0.1) / Double(grand)) }
            .sorted { $0.total > $1.total }
    }

    /// Income and expense for `count` Jalali months ending with the month of `end`, oldest first.
    static func monthlyTotals(_ entries: [LedgerEntry], endingAt end: Date, count: Int) -> [MonthlyTotal] {
        let lastMonth = Jalali.monthInterval(containing: end).start
        return (0..<count).reversed().map { back in
            let start = Jalali.adding(months: -back, to: lastMonth)
            let interval = Jalali.monthInterval(containing: start)
            let rows = Self.entries(entries, in: interval)
            return MonthlyTotal(
                monthStart: interval.start,
                income: total(rows, kind: .income),
                expense: total(rows, kind: .expense)
            )
        }
    }

    /// Spending against each budget for the month containing `date`, most used first.
    static func budgetProgress(_ budgets: [Budget], entries: [LedgerEntry], month date: Date) -> [BudgetProgress] {
        let monthRows = Self.entries(entries, in: Jalali.monthInterval(containing: date))
        return budgets.compactMap { budget -> BudgetProgress? in
            guard let category = budget.category else { return nil }
            let spent = monthRows
                .filter { $0.kind == .expense && $0.category === category }
                .reduce(Int64(0)) { $0 + $1.amount }
            return BudgetProgress(budget: budget, category: category, spent: spent)
        }
        .sorted { $0.fraction > $1.fraction }
    }

    /// Relative change, or nil when there is nothing to compare with.
    static func change(current: Int64, previous: Int64) -> Double? {
        guard previous > 0 else { return nil }
        return Double(current - previous) / Double(previous)
    }

    /// All entries as CSV (amounts in rial, Jalali dates), ready to share.
    static func csv(_ entries: [LedgerEntry]) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Jalali.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"

        func escape(_ field: String) -> String {
            guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return field }
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }

        var lines = ["date,type,amount_rial,category,account,to_account,note"]
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            lines.append([
                formatter.string(from: entry.date),
                entry.kind.rawValue,
                String(entry.amount),
                entry.category?.name ?? "",
                entry.account?.name ?? "",
                entry.toAccount?.name ?? "",
                entry.note,
            ].map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
