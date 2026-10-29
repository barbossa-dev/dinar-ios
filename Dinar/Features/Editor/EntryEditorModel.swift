import Foundation
import Observation
import SwiftData

/// Form state for creating or editing a ledger entry.
@Observable
final class EntryEditorModel {
    var kind: EntryKind {
        didSet { if kind != oldValue { category = nil } }
    }
    /// Digits typed on the keypad, in the user's display unit.
    var digits: String = ""
    var category: LedgerCategory?
    var account: Account?
    var toAccount: Account?
    var note: String = ""
    var date: Date = .now

    let editing: LedgerEntry?

    init(request: EditorRequest, unit: CurrencyUnit) {
        switch request {
        case .new(let kind):
            self.kind = kind
            self.editing = nil
        case .edit(let entry):
            self.kind = entry.kind
            self.editing = entry
            self.digits = String(entry.amount / unit.rialFactor)
            self.category = entry.category
            self.account = entry.account
            self.toAccount = entry.toAccount
            self.note = entry.note
            self.date = entry.date
        }
    }

    var isEditing: Bool { editing != nil }

    // MARK: Keypad

    func append(_ digit: Character) {
        guard digits.count < 13 else { return }
        if digits.isEmpty && digit == "0" { return }
        digits.append(digit)
    }

    func appendThousands() {
        guard !digits.isEmpty, digits.count <= 10 else { return }
        digits += "000"
    }

    func backspace() {
        if !digits.isEmpty { digits.removeLast() }
    }

    func clear() { digits = "" }

    // MARK: Validation

    func amount(in unit: CurrencyUnit) -> Int64? {
        guard let value = Int64(digits), value > 0 else { return nil }
        return value * unit.rialFactor
    }

    /// Why the form cannot be saved yet, or nil when it can.
    func validationMessage(unit: CurrencyUnit) -> String? {
        if amount(in: unit) == nil { return "مبلغ را وارد کنید" }
        if account == nil { return "یک حساب انتخاب کنید" }
        switch kind {
        case .transfer:
            if toAccount == nil || toAccount === account { return "حساب مبدأ و مقصد باید متفاوت باشند" }
        case .expense, .income:
            if category == nil { return "یک دسته‌بندی انتخاب کنید" }
        }
        return nil
    }

    /// Fills sensible defaults once the categories and accounts are known.
    func applyDefaults(categories: [LedgerCategory], accounts: [Account]) {
        if account == nil { account = accounts.first }
        if toAccount == nil { toAccount = accounts.first { $0 !== account } }
        if category == nil, let kind = kind.categoryKind {
            category = categories.first { $0.kind == kind }
        }
    }

    // MARK: Persistence

    func save(in context: ModelContext, unit: CurrencyUnit) {
        guard validationMessage(unit: unit) == nil, let amount = amount(in: unit) else { return }
        let entry = editing ?? LedgerEntry(kind: kind, amount: amount, account: account)
        entry.kind = kind
        entry.amount = amount
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.date = date
        entry.account = account
        entry.category = kind == .transfer ? nil : category
        entry.toAccount = kind == .transfer ? toAccount : nil
        if editing == nil { context.insert(entry) }
        try? context.save()
    }

    func delete(in context: ModelContext) {
        guard let editing else { return }
        context.delete(editing)
        try? context.save()
    }
}
