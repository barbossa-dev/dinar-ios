import Foundation
import Observation

/// User preferences, persisted in `UserDefaults` and observed by SwiftUI.
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var userName: String { didSet { defaults.set(userName, forKey: Keys.userName) } }
    var theme: ThemePreference { didSet { defaults.set(theme.rawValue, forKey: Keys.theme) } }
    var currencyUnit: CurrencyUnit { didSet { defaults.set(currencyUnit.rawValue, forKey: Keys.currency) } }
    var usePersianDigits: Bool { didSet { defaults.set(usePersianDigits, forKey: Keys.digits) } }
    var hideAmounts: Bool { didSet { defaults.set(hideAmounts, forKey: Keys.hide) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        userName = defaults.string(forKey: Keys.userName) ?? ""
        theme = defaults.string(forKey: Keys.theme).flatMap(ThemePreference.init) ?? .system
        currencyUnit = defaults.string(forKey: Keys.currency).flatMap(CurrencyUnit.init) ?? .toman
        usePersianDigits = defaults.object(forKey: Keys.digits) as? Bool ?? true
        hideAmounts = defaults.bool(forKey: Keys.hide)
    }

    var format: DisplayFormat {
        DisplayFormat(unit: currencyUnit, persianDigits: usePersianDigits, hideAmounts: hideAmounts)
    }

    private enum Keys {
        static let userName = "userName"
        static let theme = "theme"
        static let currency = "currencyUnit"
        static let digits = "usePersianDigits"
        static let hide = "hideAmounts"
    }
}
