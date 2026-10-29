import Foundation
import SwiftData

/// Default categories and accounts, inserted on first launch.
enum SeedData {
    private static let expenseCategories: [(String, String, String)] = [
        ("خوراک", "cart.fill", "E0B35F"),
        ("رستوران و کافه", "fork.knife", "E07A5F"),
        ("حمل‌ونقل", "bus.fill", "5B8DEF"),
        ("خودرو", "car.fill", "3D5A80"),
        ("قبوض", "bolt.fill", "2A9D8F"),
        ("اینترنت و موبایل", "wifi", "48A9C5"),
        ("مسکن و اجاره", "house.fill", "8D6E63"),
        ("خرید", "bag.fill", "D16BA5"),
        ("پوشاک", "tshirt.fill", "B388EB"),
        ("سلامت", "cross.case.fill", "EF476F"),
        ("آموزش", "graduationcap.fill", "4361EE"),
        ("تفریح", "gamecontroller.fill", "F4A261"),
        ("سفر", "airplane", "06AED5"),
        ("هدیه", "gift.fill", "E76F51"),
        ("خیریه", "heart.fill", "90BE6D"),
        ("سایر", "ellipsis", "8A909C"),
    ]

    private static let incomeCategories: [(String, String, String)] = [
        ("حقوق", "briefcase.fill", "0B7A5E"),
        ("پروژه و فریلنس", "laptopcomputer", "2A9D8F"),
        ("سرمایه‌گذاری", "chart.line.uptrend.xyaxis", "43AA8B"),
        ("اجاره", "building.2.fill", "8D6E63"),
        ("پاداش", "star.fill", "E0B35F"),
        ("هدیه", "gift.fill", "E76F51"),
        ("بازپرداخت", "arrow.uturn.backward", "5B8DEF"),
        ("سایر", "ellipsis", "8A909C"),
    ]

    /// Inserts defaults only when the store is empty, so it is safe to call on every launch.
    static func insertIfNeeded(into context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<LedgerCategory>())) ?? 0
        guard existing == 0 else { return }

        for (index, item) in expenseCategories.enumerated() {
            context.insert(LedgerCategory(name: item.0, kind: .expense, symbol: item.1, colorHex: item.2, sortOrder: index))
        }
        for (index, item) in incomeCategories.enumerated() {
            context.insert(LedgerCategory(name: item.0, kind: .income, symbol: item.1, colorHex: item.2, sortOrder: 100 + index))
        }
        context.insert(Account(name: "نقدی", kind: .cash, colorHex: "0B7A5E"))
        context.insert(Account(name: "کارت بانکی", kind: .bankCard, colorHex: "5B8DEF", createdAt: .now.addingTimeInterval(1)))
        try? context.save()
    }
}
