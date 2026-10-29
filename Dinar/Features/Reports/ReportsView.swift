import Charts
import SwiftData
import SwiftUI

enum ReportPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }
    var title: String { self == .month ? "ماهانه" : "سالانه" }
}

struct ReportsView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \LedgerEntry.date) private var entries: [LedgerEntry]

    @State private var period: ReportPeriod = .month
    @State private var anchor = Date.now
    @State private var breakdown: EntryKind = .expense

    var body: some View {
        let format = settings.format
        let step = period == .month ? 1 : 12
        let current = interval(for: anchor)
        let previous = interval(for: Jalali.adding(months: -step, to: anchor))
        let rows = Ledger.entries(entries, in: current)
        let previousRows = Ledger.entries(entries, in: previous)
        let income = Ledger.total(rows, kind: .income)
        let expense = Ledger.total(rows, kind: .expense)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("بازه", selection: $period.animation()) {
                        ForEach(ReportPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    PeriodStepper(
                        title: period == .month ? format.monthYear(anchor) : "سال \(format.year(anchor))",
                        onPrevious: { withAnimation { anchor = Jalali.adding(months: -step, to: anchor) } },
                        onNext: { withAnimation { anchor = Jalali.adding(months: step, to: anchor) } }
                    )

                    HStack(spacing: 12) {
                        StatTile(
                            title: "درآمد",
                            rial: income,
                            change: Ledger.change(current: income, previous: Ledger.total(previousRows, kind: .income)),
                            positiveIsGood: true,
                            color: Palette.income
                        )
                        StatTile(
                            title: "هزینه",
                            rial: expense,
                            change: Ledger.change(current: expense, previous: Ledger.total(previousRows, kind: .expense)),
                            positiveIsGood: false,
                            color: Palette.expense
                        )
                    }

                    BreakdownCard(
                        shares: Ledger.categoryShares(rows, kind: breakdown),
                        total: breakdown == .income ? income : expense,
                        breakdown: $breakdown
                    )

                    TrendCard(
                        months: Ledger.monthlyTotals(
                            entries,
                            endingAt: period == .month ? anchor : Jalali.adding(months: -1, to: current.end),
                            count: period == .month ? 6 : 12
                        ),
                        highlighted: Jalali.monthInterval(containing: anchor).start,
                        title: period == .month ? "شش ماه اخیر" : "ماه‌های سال"
                    )

                    InsightsCard(
                        income: income,
                        expense: expense,
                        days: max(1, Jalali.calendar.dateComponents([.day], from: current.start, to: current.end).day ?? 1),
                        top: Ledger.categoryShares(rows, kind: .expense).first
                    )
                }
                .padding()
            }
            .background { AmbientBackground() }
            .navigationTitle("گزارش‌ها")
        }
    }

    private func interval(for date: Date) -> DateInterval {
        period == .month ? Jalali.monthInterval(containing: date) : Jalali.yearInterval(containing: date)
    }
}

private struct StatTile: View {
    @Environment(AppSettings.self) private var settings
    let title: String
    let rial: Int64
    let change: Double?
    let positiveIsGood: Bool
    let color: Color

    var body: some View {
        let format = settings.format
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "circle.fill")
                .labelStyle(DotLabelStyle(color: color))
                .font(.caption)
                .foregroundStyle(.secondary)
            AmountText(rial: rial, maskable: true)
                .font(.title3.weight(.bold))
            if let change {
                let good = (change >= 0) == positiveIsGood
                Text("\(change >= 0 ? "▲" : "▼") \(format.percent(abs(change))) نسبت به قبل")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(good ? Palette.income : Palette.expense)
            } else {
                Text("—").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .glassCard(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }
}

private struct DotLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            configuration.title
        }
    }
}

private struct BreakdownCard: View {
    @Environment(AppSettings.self) private var settings
    let shares: [CategoryShare]
    let total: Int64
    @Binding var breakdown: EntryKind

    var body: some View {
        let format = settings.format
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("بر اساس دسته").font(.headline)
                Spacer()
                Picker("نوع", selection: $breakdown.animation()) {
                    Text("هزینه‌ها").tag(EntryKind.expense)
                    Text("درآمدها").tag(EntryKind.income)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            if shares.isEmpty {
                EmptyStateView(symbol: "chart.pie", title: "داده‌ای نیست", message: "در این دوره تراکنشی از این نوع ثبت نشده.")
            } else {
                Chart(shares) { share in
                    SectorMark(
                        angle: .value("مبلغ", Double(share.total)),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(share.category.color)
                    .accessibilityLabel(share.category.name)
                    .accessibilityValue(format.percent(share.share))
                }
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text(format.compact(total)).font(.title3.weight(.heavy))
                        Text(format.unit.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 210)

                VStack(spacing: 12) {
                    ForEach(shares.prefix(6)) { share in
                        HStack(spacing: 12) {
                            SymbolBadge(symbol: share.category.symbol, color: share.category.color, size: 34)
                            VStack(spacing: 6) {
                                HStack {
                                    Text(share.category.name).font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(format.percent(share.share))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    AmountText(rial: share.total, maskable: true)
                                        .font(.subheadline.weight(.semibold))
                                }
                                BudgetBar(fraction: share.share, color: share.category.color, height: 6)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .glassCard()
    }
}

private struct TrendCard: View {
    @Environment(AppSettings.self) private var settings
    let months: [MonthlyTotal]
    let highlighted: Date
    let title: String

    private struct Bar: Identifiable {
        var id: String { month + series }
        let month: String
        let series: String
        let value: Double
    }

    var body: some View {
        let format = settings.format
        let bars = months.flatMap { m in
            [
                Bar(month: format.monthName(m.monthStart), series: "درآمد", value: Double(m.income / format.unit.rialFactor)),
                Bar(month: format.monthName(m.monthStart), series: "هزینه", value: Double(m.expense / format.unit.rialFactor)),
            ]
        }

        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            Chart(bars) { bar in
                BarMark(
                    x: .value("ماه", bar.month),
                    y: .value("مبلغ", bar.value),
                    width: .ratio(0.7)
                )
                .position(by: .value("نوع", bar.series))
                .foregroundStyle(by: .value("نوع", bar.series))
                .cornerRadius(4)
            }
            .chartForegroundStyleScale(["درآمد": Palette.income, "هزینه": Palette.expense])
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(format.compact(Int64(v) * format.unit.rialFactor))
                        }
                    }
                }
            }
            .chartLegend(position: .top, alignment: .trailing)
            .frame(height: 220)
        }
        .glassCard()
    }
}

private struct InsightsCard: View {
    @Environment(AppSettings.self) private var settings
    let income: Int64
    let expense: Int64
    let days: Int
    let top: CategoryShare?

    var body: some View {
        let format = settings.format
        let savingsRate = income > 0 ? Double(income - expense) / Double(income) : 0
        VStack(alignment: .leading, spacing: 14) {
            Text("نکته‌ها").font(.headline)
            row("میانگین هزینه‌ی روزانه", format.amount(expense / Int64(days)) + " " + format.unit.title)
            row("نرخ پس‌انداز", format.percent(savingsRate), color: savingsRate >= 0 ? Palette.income : Palette.expense)
            row("مانده‌ی دوره", format.signed(income - expense) + " " + format.unit.title)
            if let top {
                row("بیشترین هزینه", "\(top.category.name) (\(format.percent(top.share)))")
            }
        }
        .glassCard()
    }

    private func row(_ title: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.bold).foregroundStyle(color)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
