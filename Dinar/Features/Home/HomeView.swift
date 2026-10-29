import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt)
    private var accounts: [Account]

    @Query(sort: \LedgerEntry.date, order: .reverse)
    private var entries: [LedgerEntry]

    @Query private var budgets: [Budget]

    var body: some View {
        let now = Date.now
        let monthRows = Ledger.entries(entries, in: Jalali.monthInterval(containing: now))
        let progress = Ledger.budgetProgress(budgets, entries: monthRows, month: now)

        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCard(
                        total: accounts.reduce(0) { $0 + $1.balance },
                        income: Ledger.total(monthRows, kind: .income),
                        expense: Ledger.total(monthRows, kind: .expense),
                        budgetLimit: progress.reduce(0) { $0 + $1.limit },
                        budgetSpent: progress.reduce(0) { $0 + $1.spent },
                        month: now
                    )
                    QuickActions()
                    if !accounts.isEmpty {
                        AccountsStrip(accounts: accounts)
                    }
                    RecentEntries(entries: Array(entries.prefix(6)))
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background { AmbientBackground() }
            .navigationTitle(greeting)
            .navigationSubtitle(settings.userName.isEmpty ? "دینار" : settings.userName)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        withAnimation { settings.hideAmounts.toggle() }
                    } label: {
                        Image(systemName: settings.hideAmounts ? "eye" : "eye.slash")
                    }
                    .accessibilityLabel(settings.hideAmounts ? "نمایش مبالغ" : "پنهان کردن مبالغ")

                    Button {
                        router.isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("تنظیمات")
                }
            }
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "صبح بخیر"
        case 12..<17: "ظهر بخیر"
        case 17..<21: "عصر بخیر"
        default: "شب بخیر"
        }
    }
}

// MARK: - Balance

private struct BalanceCard: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    let total: Int64
    let income: Int64
    let expense: Int64
    let budgetLimit: Int64
    let budgetSpent: Int64
    let month: Date

    var body: some View {
        let format = settings.format
        let budgetFraction = budgetLimit > 0 ? Double(budgetSpent) / Double(budgetLimit) : 0

        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("موجودی کل")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onBalanceCardMuted)
                Spacer()
                Text(format.monthYear(month))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.clear, in: .capsule)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                AmountText(rial: total, maskable: true)
                    .font(.system(size: 38, weight: .heavy))
                Text(format.unit.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.onBalanceCardMuted)
            }

            HStack(spacing: 12) {
                FlowStat(title: "درآمد این ماه", symbol: EntryKind.income.symbol, rial: income)
                FlowStat(title: "هزینه این ماه", symbol: EntryKind.expense.symbol, rial: expense)
            }

            if budgetLimit > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("بودجه‌ی ماه").foregroundStyle(Palette.onBalanceCardMuted)
                        Spacer()
                        Text("\(format.percent(budgetFraction)) مصرف شده").fontWeight(.semibold)
                    }
                    .font(.caption)
                    BudgetBar(fraction: budgetFraction, color: budgetFraction > 0.9 ? .red : Palette.gold, height: 6)
                }
            } else {
                Button("تعیین بودجه ماهانه") { router.selectedTab = .budgets }
                    .buttonStyle(.glass)
                    .font(.footnote.weight(.semibold))
            }
        }
        .foregroundStyle(Palette.onBalanceCard)
        .padding(22)
        // Strongly tinted glass keeps the hero card legible while still refracting the background.
        .glassEffect(.regular.tint(Palette.balanceCard.opacity(0.88)), in: .rect(cornerRadius: 32))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
    }
}

private struct FlowStat: View {
    let title: String
    let symbol: String
    let rial: Int64

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.bold))
                .frame(width: 34, height: 34)
                .glassEffect(.clear, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(Palette.onBalanceCardMuted)
                AmountText(rial: rial, maskable: true).font(.subheadline.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Quick actions

private struct QuickActions: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(EntryKind.allCases) { kind in
                    Button {
                        router.newEntry(kind)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(kind.color)
                            Text(kind.title)
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 76)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
                }
            }
        }
    }
}

// MARK: - Accounts

private struct AccountsStrip: View {
    let accounts: [Account]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("حساب‌ها")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(accounts) { account in
                        VStack(alignment: .leading, spacing: 10) {
                            SymbolBadge(symbol: account.kind.symbol, color: account.color, size: 36)
                            Text(account.name)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            AmountText(rial: account.balance, maskable: true)
                                .font(.headline)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(16)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }
}

// MARK: - Recent

private struct RecentEntries: View {
    @Environment(AppRouter.self) private var router
    let entries: [LedgerEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("تراکنش‌های اخیر")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("مشاهده همه") { router.selectedTab = .transactions }
                    .font(.subheadline.weight(.semibold))
            }

            VStack(spacing: 0) {
                if entries.isEmpty {
                    EmptyStateView(
                        symbol: "list.bullet.rectangle",
                        title: "هنوز تراکنشی ثبت نشده",
                        message: "اولین هزینه یا درآمدت را ثبت کن تا دینار برایت حساب‌وکتاب کند."
                    )
                } else {
                    ForEach(entries) { entry in
                        Button { router.edit(entry) } label: {
                            EntryRow(entry: entry).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        if entry.id != entries.last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
    }
}
