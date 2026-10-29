import SwiftData
import SwiftUI

struct TransactionsView: View {
    @Environment(AppSettings.self) private var settings
    @State private var month = Date.now
    @State private var query = ""
    @State private var kindFilter: EntryKind?

    var body: some View {
        NavigationStack {
            MonthEntriesList(
                interval: Jalali.monthInterval(containing: month),
                query: query,
                kindFilter: kindFilter
            )
            .safeAreaInset(edge: .top) {
                PeriodStepper(
                    title: settings.format.monthYear(month),
                    onPrevious: { withAnimation { month = Jalali.adding(months: -1, to: month) } },
                    onNext: { withAnimation { month = Jalali.adding(months: 1, to: month) } }
                )
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
            .background { AmbientBackground() }
            .searchable(text: $query, prompt: "جستجو در یادداشت‌ها و دسته‌ها")
            .navigationTitle("تراکنش‌ها")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("نوع تراکنش", selection: $kindFilter) {
                            Label("همه", systemImage: "square.stack.3d.up").tag(EntryKind?.none)
                            ForEach(EntryKind.allCases) { kind in
                                Label(kind.title, systemImage: kind.symbol).tag(Optional(kind))
                            }
                        }
                    } label: {
                        Image(systemName: kindFilter == nil
                            ? "line.3.horizontal.decrease"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("فیلتر نوع تراکنش")
                }
            }
        }
    }
}

/// The entries of one month. Split out so `@Query` can be rebuilt when the month changes.
private struct MonthEntriesList: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router

    @Query private var entries: [LedgerEntry]
    private let query: String
    private let kindFilter: EntryKind?

    init(interval: DateInterval, query: String, kindFilter: EntryKind?) {
        let start = interval.start
        let end = interval.end
        _entries = Query(
            filter: #Predicate<LedgerEntry> { $0.date >= start && $0.date < end },
            sort: \LedgerEntry.date,
            order: .reverse
        )
        self.query = query
        self.kindFilter = kindFilter
    }

    private var filtered: [LedgerEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return entries.filter { entry in
            (kindFilter == nil || entry.kind == kindFilter) &&
                (trimmed.isEmpty ||
                    entry.note.localizedStandardContains(trimmed) ||
                    (entry.category?.name.localizedStandardContains(trimmed) ?? false))
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [LedgerEntry]
        var id: Date { day }
    }

    private var days: [DayGroup] {
        let calendar = Jalali.calendar
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        let format = settings.format
        let rows = filtered

        List {
            Section {
                HStack {
                    SummaryCell(title: "درآمد", rial: Ledger.total(rows, kind: .income), color: Palette.income)
                    SummaryCell(title: "هزینه", rial: Ledger.total(rows, kind: .expense), color: Palette.expense)
                    SummaryCell(
                        title: "خالص",
                        rial: Ledger.total(rows, kind: .income) - Ledger.total(rows, kind: .expense),
                        color: .primary
                    )
                }
            }

            if rows.isEmpty {
                EmptyStateView(
                    symbol: query.isEmpty && kindFilter == nil ? "tray" : "magnifyingglass",
                    title: query.isEmpty && kindFilter == nil ? "این ماه تراکنشی ندارد" : "نتیجه‌ای پیدا نشد",
                    message: query.isEmpty && kindFilter == nil
                        ? "از دکمه‌ی «تراکنش جدید» پایین صفحه شروع کن."
                        : "عبارت یا فیلتر دیگری را امتحان کن."
                )
                .listRowBackground(Color.clear)
            }

            ForEach(days) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button { router.edit(entry) } label: {
                            EntryRow(entry: entry, showsDate: false)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                withAnimation { context.delete(entry) }
                            } label: {
                                Label("حذف", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button { router.edit(entry) } label: {
                                Label("ویرایش", systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                    }
                } header: {
                    HStack {
                        Text(dayTitle(group.day, format: format))
                        Spacer()
                        AmountText(rial: group.entries.reduce(0) { $0 + $1.signedAmount }, signed: true)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .animation(.default, value: rows.count)
    }

    private func dayTitle(_ day: Date, format: DisplayFormat) -> String {
        let relative = format.relativeDay(day)
        return relative == "امروز" || relative == "دیروز" ? relative : format.weekdayDayMonth(day)
    }
}

private struct SummaryCell: View {
    let title: String
    let rial: Int64
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            AmountText(rial: rial, maskable: true)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
