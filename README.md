# Dinar for iOS

A Persian personal finance app built with SwiftUI, SwiftData and iOS 26 Liquid Glass.

## Getting started

1. Open `Dinar.xcodeproj` in **Xcode 26** or newer.
2. Under Signing & Capabilities, pick your team (and change the bundle ID if needed).
3. Run on an iOS 26 simulator or device (`⌘R`). Run the tests with `⌘U`.

The project uses Xcode synchronized folders: any file added under `Dinar/` is picked up
automatically.

## Architecture

```
Dinar/
  App/              Entry point, router and the root TabView
  Core/
    Model/          SwiftData models: Account, LedgerCategory, LedgerEntry, Budget
    Ledger/         Pure business logic: totals, category shares, monthly trend, budgets, CSV
    Formatting/     Persian calendar (Calendar.persian) and Persian money/date formatting
    Settings/       User preferences with @Observable and UserDefaults
  DesignSystem/     Colors and shared glass components
  Features/
    Home/           Dashboard: balance card, quick actions, accounts, recent entries
    Transactions/   Monthly list with search, filters and swipe actions
    Editor/         Add/edit entries with a glass keypad
    Reports/        Donut and bar charts with Swift Charts
    Budgets/        Monthly budget per category
    Settings/       Theme, currency unit, Persian digits, accounts, CSV export
DinarTests/         Tests with Swift Testing
```

- **SwiftUI + SwiftData + Observation**, no third-party dependencies.
- Views fetch with `@Query`; calculations live in `Ledger`, a set of pure, tested functions.
- Amounts are always stored in **rial** as `Int64` and converted to toman or rial only for display.
- Dates use Foundation's built-in Persian calendar, including the date picker.
- The whole UI, including navigation and tab bars, is right-to-left.
- Default `MainActor` isolation and Approachable Concurrency, matching the Xcode 26 project template.

## Liquid Glass

- Glass tab bar that minimizes on scroll (`tabBarMinimizeBehavior`) with a "New transaction"
  button in `tabViewBottomAccessory`.
- Cards, quick actions, categories and the keypad use `glassEffect` and `GlassEffectContainer`.
- `.glass` / `.glassProminent` button styles and the new `close` / `confirm` toolbar roles.
- A soft gold ambient background for the glass to refract.

## Release builds (IPA)

The project is set up for App Store distribution:

- Team `7UJ4DNP6MK`, bundle ID `ir.famastudio.dinar`, automatic signing.
- `PrivacyInfo.xcprivacy` declares no tracking and no data collection, plus the required
  reason for `UserDefaults` (`CA92.1`).
- `ITSAppUsesNonExemptEncryption = NO`, so App Store Connect skips the export-compliance question.
- A shared `Dinar` scheme, so command-line builds work without opening Xcode first.

Build a signed IPA:

```bash
scripts/build-ipa.sh            # App Store Connect IPA → build/ios/Dinar.ipa
scripts/build-ipa.sh adhoc      # Ad Hoc IPA for registered test devices
```

The script runs the tests, archives the Release configuration, and exports the IPA.
The build number defaults to a timestamp (`BUILD_NUMBER=42` overrides it); bump
`MARKETING_VERSION` in Xcode for each new public version. Upload the IPA with the
**Transporter** app, or use Xcode → Product → Archive → Distribute App.

Before the first upload, create the app record in App Store Connect with the same bundle ID,
and make sure your Apple ID is signed in under Xcode → Settings → Accounts.

## Store assets

`store/` holds App Store screenshots: iPhone 6.9" (1320×2868), iPhone 6.5" (1284×2778)
and iPad 13" (2064×2752).

## Before publishing

- The current icon is a simple coin with light, dark and tinted variants; you can build a final
  icon with Icon Composer.
- In App Store Connect, answer the App Privacy questions with "Data Not Collected".
- Take screenshots from the simulator in both light and dark themes.
