import SwiftData
import SwiftUI

struct EntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt)
    private var accounts: [Account]

    @State private var model: EntryEditorModel
    @State private var isConfirmingDelete = false
    @State private var validationMessage: String?

    init(request: EditorRequest, unit: CurrencyUnit) {
        _model = State(initialValue: EntryEditorModel(request: request, unit: unit))
    }

    var body: some View {
        @Bindable var model = model
        let unit = settings.currencyUnit

        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("نوع تراکنش", selection: $model.kind.animation(.snappy)) {
                        ForEach(EntryKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    AmountDisplay(model: model)

                    DetailsBar(model: model, accounts: accounts)

                    if model.kind == .transfer {
                        TransferPreview(from: model.account, to: model.toAccount)
                    } else {
                        CategoryGrid(
                            categories: categories.filter { $0.kind == model.kind.categoryKind },
                            selection: $model.category
                        )
                    }

                    TextField("یادداشت (اختیاری)", text: $model.note, axis: .vertical)
                        .lineLimit(1...3)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))

                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                            .transition(.opacity)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Keypad(model: model)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .background { AmbientBackground() }
            .navigationTitle(model.isEditing ? "ویرایش تراکنش" : "تراکنش جدید")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("بستن")
                }
                if model.isEditing {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(role: .destructive) { isConfirmingDelete = true } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("حذف تراکنش")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save(unit: unit) } label: { Image(systemName: "checkmark") }
                        .accessibilityLabel(model.isEditing ? "ذخیره تغییرات" : "ثبت تراکنش")
                }
            }
            .confirmationDialog("این تراکنش حذف شود؟", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("حذف تراکنش", role: .destructive) {
                    model.delete(in: context)
                    dismiss()
                }
            } message: {
                Text("موجودی حساب‌ها دوباره محاسبه می‌شود.")
            }
            .onAppear { model.applyDefaults(categories: categories, accounts: accounts) }
            .onChange(of: model.kind) { model.applyDefaults(categories: categories, accounts: accounts) }
        }
        .presentationDragIndicator(.visible)
    }

    private func save(unit: CurrencyUnit) {
        if let message = model.validationMessage(unit: unit) {
            withAnimation { validationMessage = message }
            return
        }
        model.save(in: context, unit: unit)
        dismiss()
    }
}

// MARK: - Amount

private struct AmountDisplay: View {
    @Environment(AppSettings.self) private var settings
    let model: EntryEditorModel

    var body: some View {
        let format = settings.format
        let value = Int64(model.digits) ?? 0
        VStack(spacing: 4) {
            Text("مبلغ")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(format.amount(value * format.unit.rialFactor))
                    .font(.system(size: 46, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(model.digits.isEmpty ? Color.secondary : model.kind.color)
                    .contentTransition(.numericText(value: Double(value)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(format.unit.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .animation(.snappy, value: model.digits)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Date and accounts

private struct DetailsBar: View {
    @Bindable var model: EntryEditorModel
    let accounts: [Account]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    DatePicker("تاریخ", selection: $model.date, in: ...Date.now.addingTimeInterval(86_400 * 365), displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)

                    AccountMenu(
                        prefix: model.kind == .transfer ? "از" : nil,
                        accounts: accounts,
                        selection: $model.account
                    )
                    if model.kind == .transfer {
                        AccountMenu(prefix: "به", accounts: accounts, selection: $model.toAccount)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .scrollClipDisabled()
    }
}

private struct AccountMenu: View {
    let prefix: String?
    let accounts: [Account]
    @Binding var selection: Account?

    var body: some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    selection = account
                } label: {
                    Label(account.name, systemImage: selection === account ? "checkmark" : account.kind.symbol)
                }
            }
        } label: {
            Label(
                [prefix, selection?.name ?? "انتخاب حساب"].compactMap { $0 }.joined(separator: " "),
                systemImage: selection?.kind.symbol ?? "wallet.bifold"
            )
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MARK: - Categories

private struct CategoryGrid: View {
    let categories: [LedgerCategory]
    @Binding var selection: LedgerCategory?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
            ForEach(categories) { category in
                let isSelected = selection === category
                Button {
                    withAnimation(.snappy) { selection = category }
                } label: {
                    VStack(spacing: 6) {
                        SymbolBadge(symbol: category.symbol, color: category.color, size: 38)
                        Text(category.name)
                            .font(.caption2.weight(isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 78)
                }
                .buttonStyle(.plain)
                .glassEffect(
                    isSelected ? .regular.tint(category.color.opacity(0.35)).interactive() : .regular.interactive(),
                    in: .rect(cornerRadius: 18)
                )
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18).strokeBorder(category.color, lineWidth: 2)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection?.persistentModelID)
    }
}

private struct TransferPreview: View {
    let from: Account?
    let to: Account?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                bubble(from)
                Image(systemName: "arrow.backward")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Palette.transfer)
                bubble(to)
            }
            Text("انتقال بین حساب‌ها روی موجودی کل اثری ندارد.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func bubble(_ account: Account?) -> some View {
        VStack(spacing: 6) {
            SymbolBadge(symbol: account?.kind.symbol ?? "questionmark", color: account?.color ?? .secondary, size: 54)
            Text(account?.name ?? "—").font(.footnote.weight(.semibold))
        }
    }
}

// MARK: - Keypad

/// Phone-style keypad on Liquid Glass. Always left-to-right, like every numeric keypad.
private struct Keypad: View {
    @Environment(AppSettings.self) private var settings
    let model: EntryEditorModel

    private let rows: [[Character]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        let persian = settings.usePersianDigits
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { digit in
                            key(persian ? String(digit).persianDigits : String(digit)) { model.append(digit) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    key(persian ? "۰۰۰" : "000") { model.appendThousands() }
                    key(persian ? "۰" : "0") { model.append("0") }
                    Button { model.backspace() } label: {
                        Image(systemName: "delete.backward")
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .accessibilityLabel("پاک کردن رقم آخر")
                    .simultaneousGesture(LongPressGesture().onEnded { _ in model.clear() })
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .sensoryFeedback(.impact(weight: .light), trigger: model.digits)
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }
}
