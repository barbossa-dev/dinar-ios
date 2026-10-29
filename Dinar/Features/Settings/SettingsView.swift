import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Query private var entries: [LedgerEntry]

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section("پروفایل") {
                    TextField("نام شما", text: $settings.userName)
                        .textContentType(.givenName)
                }

                Section("ظاهر") {
                    Picker("تم", selection: $settings.theme) {
                        ForEach(ThemePreference.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("واحد پول", selection: $settings.currencyUnit) {
                        ForEach(CurrencyUnit.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("ارقام فارسی", isOn: $settings.usePersianDigits)
                    Toggle("پنهان کردن مبالغ", isOn: $settings.hideAmounts)
                } header: {
                    Text("نمایش اعداد")
                } footer: {
                    Text("مبالغ همیشه به ریال ذخیره می‌شوند؛ تغییر واحد فقط نمایش را عوض می‌کند.")
                }

                Section("حساب‌ها") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("مدیریت حساب‌ها", systemImage: "creditcard")
                    }
                }

                Section {
                    ShareLink(
                        item: CSVExport(text: Ledger.csv(entries)),
                        preview: SharePreview("تراکنش‌های دینار", image: Image(systemName: "tablecells"))
                    ) {
                        Label("خروجی CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                } header: {
                    Text("داده‌ها")
                } footer: {
                    Text("همه‌ی داده‌ها فقط روی همین دستگاه ذخیره می‌شوند.")
                }

                Section {
                    LabeledContent("نسخه", value: appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .navigationTitle("تنظیمات")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("بستن")
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return settings.format.persianDigits ? version.persianDigits : version
    }
}

/// A CSV document that opens correctly in Excel and Numbers (UTF-8 with BOM).
nonisolated struct CSVExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(("\u{FEFF}" + export.text).utf8)
        }
        .suggestedFileName("dinar-transactions.csv")
    }
}
