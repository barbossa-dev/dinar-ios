import Foundation

/// Direction of money for a ledger entry.
enum EntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expense: "هزینه"
        case .income: "درآمد"
        case .transfer: "انتقال"
        }
    }

    var symbol: String {
        switch self {
        case .expense: "arrow.up.right"
        case .income: "arrow.down.left"
        case .transfer: "arrow.left.arrow.right"
        }
    }

    /// The category kind entries of this kind use, if any.
    var categoryKind: CategoryKind? {
        switch self {
        case .expense: .expense
        case .income: .income
        case .transfer: nil
        }
    }
}

enum CategoryKind: String, Codable, Sendable {
    case expense
    case income
}

enum AccountKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case cash
    case bankCard
    case savings
    case wallet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "نقدی"
        case .bankCard: "کارت بانکی"
        case .savings: "پس‌انداز"
        case .wallet: "کیف پول"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote.fill"
        case .bankCard: "creditcard.fill"
        case .savings: "building.columns.fill"
        case .wallet: "wallet.bifold.fill"
        }
    }
}

/// Amounts are always stored in rial; this is only how they are shown.
enum CurrencyUnit: String, CaseIterable, Identifiable, Sendable {
    case toman
    case rial

    var id: String { rawValue }

    var rialFactor: Int64 {
        switch self {
        case .toman: 10
        case .rial: 1
        }
    }

    var title: String {
        switch self {
        case .toman: "تومان"
        case .rial: "ریال"
        }
    }
}

enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "مطابق سیستم"
        case .light: "روشن"
        case .dark: "تیره"
        }
    }
}
