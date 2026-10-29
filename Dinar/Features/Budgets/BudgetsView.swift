import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var budgets: [Budget]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query private var entries: [LedgerEntry]

    @State private var editing: BudgetSheetTarget?

    var body: some View {
        let now = Date.now
        let progress = Ledger.budgetProgress(budgets, entries: entries, month: now)
        let unbudgeted = categories.filter { $0.kind == .expense && $0.budget == nil }

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if progress.isEmpty {
                        EmptyStateView(
                            symbol: "gauge.with.needle",
                            title: "هنوز بودجه‌ای تعیین نکرده‌ای",
                            message: "برای هر دسته سقف خرج ماهانه بگذار تا دینار قبل از عبور از آن خبرت کند."
                        )
                        .padding(.top, 40)
                    } else {
                        OverviewCard(progress: progress, month: now)
                        ForEach(progress) { item in
                            Button { editing = .existing(item.budget) } label: {
                                BudgetRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background { AmbientBackground() }
            .navigationTitle("بودجه")
            .toolbar {
                if !unbudgeted.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { editing = .new } label: {
                            Label("بودجه جدید", systemImage: "plus")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
            .sheet(item: $editing) { target in
                BudgetEditorSheet(target: target, available: unbudgeted, unit: settings.currencyUnit)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

enum BudgetSheetTarget: Identifiable {
    case new
    case existing(Budget)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let budget): "\(budget.persistentModelID.hashValue)"
        }
    }
}

private struct OverviewCard: View {
    @Environment(AppSettings.self) private var settings
    let progress: [BudgetProgress]
    let month: Date

    var body: some View {
        let format = settings.format
        let limit = progress.reduce(Int64(0)) { $0 + $1.limit }
        let spent = progress.reduce(Int64(0)) { $0 + $1.spent }
        let daysLeft = Jalali.daysLeftInMonth(from: month)
        let fraction = limit > 0 ? Double(spent) / Double(limit) : 0
        let perDay = max(0, (limit - spent) / Int64(daysLeft))

        VStack(alignment: .leading, spacing: 12) {
            Text("بودجه‌ی \(format.monthYear(month))")
                .font(.subheadline)
                .foregroundStyle(Palette.onBalanceCardMuted)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AmountText(rial: limit - spent, maskable: true).font(.system(size: 32, weight: .heavy))
                Text("\(format.unit.title) باقی‌مانده").font(.footnote).foregroundStyle(Palette.onBalanceCardMuted)
            }
            BudgetBar(fraction: fraction, color: Palette.gold)
            HStack {
                Text("\(format.amount(spent)) از \(format.amount(limit))")
                Spacer()
                Text("\(format.number(daysLeft)) روز مانده")
            }
            .font(.caption.weight(.semibold))
            if perDay > 0 {
                Text("می‌توانی روزانه تا \(format.amount(perDay)) \(format.unit.title) خرج کنی.")
                    .font(.caption)
                    .foregroundStyle(Palette.onBalanceCardMuted)
            }
        }
        .foregroundStyle(Palette.onBalanceCard)
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Palette.balanceCard.opacity(0.88)), in: .rect(cornerRadius: 30))
    }
}

private struct BudgetRow: View {
    @Environment(AppSettings.self) private var settings
    let item: BudgetProgress

    var body: some View {
        let format = settings.format
        let status: Color = item.isOver ? Color.red : (item.isNearLimit ? Palette.warning : item.category.color)

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                SymbolBadge(symbol: item.category.symbol, color: item.category.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.category.name).font(.subheadline.weight(.semibold))
                    Text(item.isOver
                        ? "\(format.amount(-item.remaining)) بیشتر از بودجه"
                        : "\(format.amount(item.remaining)) \(format.unit.title) باقی‌مانده")
                        .font(.caption)
                        .foregroundStyle(item.isOver ? Color.red : Color.secondary)
                }
                Spacer()
                Text(format.percent(item.fraction))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(status)
            }
            BudgetBar(fraction: item.fraction, color: status)
            HStack {
                AmountText(rial: item.spent)
                Spacer()
                AmountText(rial: item.limit)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

private struct BudgetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    let target: BudgetSheetTarget
    let available: [LedgerCategory]
    let unit: CurrencyUnit

    @State private var category: LedgerCategory?
    @State private var amountText = ""

    var body: some View {
        let format = settings.format
        NavigationStack {
            Form {
                if case .existing(let budget) = target {
                    Section {
                        Label(budget.category?.name ?? "", systemImage: budget.category?.symbol ?? "circle")
                    }
                } else {
                    Section("دسته") {
                        Picker("دسته", selection: $category) {
                            ForEach(available) { c in
                                Label(c.name, systemImage: c.symbol).tag(Optional(c))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
                Section {
                    TextField("سقف ماهانه", text: $amountText)
                        .keyboardType(.numberPad)
                        .onChange(of: amountText) { _, value in
                            let digits = String(value.latinDigits.filter(\.isNumber).prefix(13))
                            if digits != value { amountText = digits }
                        }
                } header: {
                    Text("سقف ماهانه (\(unit.title))")
                } footer: {
                    if let rial = format.rial(fromInput: amountText) {
                        Text("\(format.amount(rial)) \(unit.title)")
                    }
                }
                if case .existing(let budget) = target {
                    Section {
                        Button("حذف بودجه", role: .destructive) {
                            context.delete(budget)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "بودجه جدید" : "ویرایش بودجه")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { save() } label: { Image(systemName: "checkmark") }
                        .disabled(format.rial(fromInput: amountText) == nil || (isNew && category == nil))
                }
            }
            .onAppear(perform: load)
        }
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func load() {
        switch target {
        case .new:
            category = available.first
        case .existing(let budget):
            amountText = String(budget.monthlyLimit / unit.rialFactor)
        }
    }

    private func save() {
        guard let rial = settings.format.rial(fromInput: amountText), rial > 0 else { return }
        switch target {
        case .new:
            guard let category else { return }
            context.insert(Budget(monthlyLimit: rial, category: category))
        case .existing(let budget):
            budget.monthlyLimit = rial
        }
        try? context.save()
        dismiss()
    }
}
