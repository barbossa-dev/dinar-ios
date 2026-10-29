import SwiftUI
import UIKit

extension Color {
    /// `Color(hex: "E0B35F")`
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A color that adapts to light and dark appearance.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Dinar's palette: a warm ink neutral and coin gold.
enum Palette {
    static let gold = Color(hex: "E0B35F")
    static let goldDeep = Color(hex: "8A6416")
    static let ink = Color(hex: "16181D")
    static let paper = Color(hex: "F5F3EE")
    static let night = Color(hex: "0D0F13")

    static let background = Color(light: paper, dark: night)
    static let income = Color(light: Color(hex: "0B7A5E"), dark: Color(hex: "3CCB9F"))
    static let expense = Color(light: Color(hex: "C2410C"), dark: Color(hex: "FF9466"))
    static let transfer = Color(light: Color(hex: "3D5A80"), dark: Color(hex: "8FB3E8"))
    static let warning = Color(light: Color(hex: "B45309"), dark: Color(hex: "FBBF24"))

    /// The hero balance card: ink in light mode, gold in dark mode.
    static let balanceCard = Color(light: ink, dark: gold)
    static let onBalanceCard = Color(light: Color(hex: "F5F3EE"), dark: Color(hex: "17140D"))
    static let onBalanceCardMuted = Color(light: Color(hex: "A7ABB4"), dark: Color(hex: "5C4618"))
}

extension LedgerCategory {
    var color: Color { Color(hex: colorHex) }
}

extension Account {
    var color: Color { Color(hex: colorHex) }
}

extension EntryKind {
    var color: Color {
        switch self {
        case .expense: Palette.expense
        case .income: Palette.income
        case .transfer: Palette.transfer
        }
    }
}
