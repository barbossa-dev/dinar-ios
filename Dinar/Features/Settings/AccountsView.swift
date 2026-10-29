import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt)
    private var accounts: [Account]

    @State private var isAdding = false
    @State private var archiveCandidate: Account?

    var body: some View {
        List {
            ForEach(accounts) { account in
                HStack(spacing: 12) {
                    SymbolBadge(symbol: account.kind.symbol, color: account.color, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name).font(.body.weight(.semibold))
                        Text(account.kind.title).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    AmountText(rial: account.balance, maskable: true).font(.subheadline.weight(.semibold))
                }
                .swipeActions {
                    if accounts.count > 1 {
                        Button("بایگانی", systemImage: "archivebox") { archiveCandidate = account }
                            .tint(.orange)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { AmbientBackground() }
        .navigationTitle("حساب‌ها")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: { Label("حساب جدید", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $isAdding) {
            AccountEditorSheet(colorIndex: accounts.count)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "بایگانی حساب؟",
            isPresented: Binding(get: { archiveCandidate != nil }, set: { if !$0 { archiveCandidate = nil } }),
            titleVisibility: .visible,
            presenting: archiveCandidate
        ) { account in
            Button("بایگانی «\(account.name)»", role: .destructive) {
                account.isArchived = true
                try? context.save()
            }
        } message: { _ in
            Text("حساب از فهرست‌ها پنهان می‌شود ولی تراکنش‌های قبلی آن باقی می‌مانند.")
        }
    }
}

private struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    let colorIndex: Int
    @State private var name = ""
    @State private var kind: AccountKind = .bankCard
    @State private var balanceText = ""

    private static let colors = ["0B7A5E", "5B8DEF", "E0B35F", "D16BA5", "E07A5F", "2A9D8F"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("نام حساب", text: $name)
                Picker("نوع", selection: $kind) {
                    ForEach(AccountKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                TextField("موجودی فعلی (\(settings.currencyUnit.title))", text: $balanceText)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("حساب جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        let account = Account(
                            name: name.trimmingCharacters(in: .whitespaces),
                            kind: kind,
                            initialBalance: settings.format.rial(fromInput: balanceText) ?? 0,
                            colorHex: Self.colors[colorIndex % Self.colors.count]
                        )
                        context.insert(account)
                        try? context.save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
