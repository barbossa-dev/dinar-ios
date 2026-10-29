import SwiftData
import SwiftUI
import UIKit

@main
struct DinarApp: App {
    @State private var settings = AppSettings()
    @State private var router = AppRouter()

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Account.self, LedgerCategory.self, LedgerEntry.self, Budget.self)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
        SeedData.insertIfNeeded(into: container.mainContext)

        // Dinar is a Persian app: lay out system bars (navigation, tab bar) right-to-left
        // too, not only SwiftUI content, regardless of the device language.
        UIView.appearance().semanticContentAttribute = .forceRightToLeft
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, settings.format.locale)
                .environment(\.calendar, Jalali.calendar)
                .preferredColorScheme(colorScheme)
                .tint(Color(light: Palette.ink, dark: Palette.gold))
        }
        .modelContainer(container)
    }

    private var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
