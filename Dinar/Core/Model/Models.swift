import Foundation
import SwiftData

@Model
final class Account {
    var name: String
    var kindRaw: String
    /// Balance when the account was added to Dinar, in rial.
    var initialBalance: Int64
    var colorHex: String
    var isArchived: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LedgerEntry.account)
    var entries: [LedgerEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \LedgerEntry.toAccount)
    var incomingTransfers: [LedgerEntry] = []

    init(name: String, kind: AccountKind, initialBalance: Int64 = 0, colorHex: String, createdAt: Date = .now) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.initialBalance = initialBalance
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = createdAt
    }

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .cash }
        set { kindRaw = newValue.rawValue }
    }

    /// Live balance: initial + income − expense − transfers out + transfers in.
    var balance: Int64 {
        let outgoing = entries.reduce(Int64(0)) { sum, entry in
            entry.kind == .income ? sum + entry.amount : sum - entry.amount
        }
        let incoming = incomingTransfers.reduce(Int64(0)) { $0 + $1.amount }
        return initialBalance + outgoing + incoming
    }
}

@Model
final class LedgerCategory {
    var name: String
    var kindRaw: String
    /// An SF Symbol name.
    var symbol: String
    var colorHex: String
    var sortOrder: Int

    @Relationship(deleteRule: .nullify, inverse: \LedgerEntry.category)
    var entries: [LedgerEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budget: Budget?

    init(name: String, kind: CategoryKind, symbol: String, colorHex: String, sortOrder: Int) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.symbol = symbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var kind: CategoryKind { CategoryKind(rawValue: kindRaw) ?? .expense }
}

/// A single income, expense or transfer. Named to avoid clashing with SwiftUI's `Transaction`.
@Model
final class LedgerEntry {
    var kindRaw: String
    /// Always positive, in rial. `kind` decides the direction.
    var amount: Int64
    var note: String
    var date: Date
    var category: LedgerCategory?
    var account: Account?
    /// Destination account; only for transfers.
    var toAccount: Account?

    init(
        kind: EntryKind,
        amount: Int64,
        note: String = "",
        date: Date = .now,
        category: LedgerCategory? = nil,
        account: Account?,
        toAccount: Account? = nil
    ) {
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.note = note
        self.date = date
        self.category = category
        self.account = account
        self.toAccount = toAccount
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    /// Effect on total wealth; transfers are neutral.
    var signedAmount: Int64 {
        switch kind {
        case .income: amount
        case .expense: -amount
        case .transfer: 0
        }
    }

    /// The title shown in lists.
    var title: String {
        switch kind {
        case .transfer: "انتقال به \(toAccount?.name ?? "—")"
        default: note.isEmpty ? (category?.name ?? "بدون دسته") : note
        }
    }
}

/// A monthly spending limit for one expense category.
@Model
final class Budget {
    var monthlyLimit: Int64
    var category: LedgerCategory?

    init(monthlyLimit: Int64, category: LedgerCategory?) {
        self.monthlyLimit = monthlyLimit
        self.category = category
    }
}
