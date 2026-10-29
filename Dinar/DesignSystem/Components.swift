import SwiftUI

/// Soft gold and ink glows behind the content, so Liquid Glass has something to refract.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Palette.background
            Circle()
                .fill(Palette.gold.opacity(scheme == .dark ? 0.22 : 0.35))
                .frame(width: 420, height: 420)
                .blur(radius: 110)
                .offset(x: 140, y: -320)
            Circle()
                .fill((scheme == .dark ? Palette.gold : Palette.ink).opacity(scheme == .dark ? 0.08 : 0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: -160, y: 260)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// A content card on Liquid Glass.
    func glassCard(cornerRadius: CGFloat = 26, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// A tinted circular badge with an SF Symbol.
struct SymbolBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: .circle)
            .accessibilityHidden(true)
    }
}

/// Money text that follows the user's unit, digit and privacy settings.
struct AmountText: View {
    @Environment(AppSettings.self) private var settings
    let rial: Int64
    var signed = false
    var maskable = false
    var showUnit = false

    var body: some View {
        let format = settings.format
        let value = signed ? format.signed(rial) : format.amount(rial)
        let text = maskable ? format.masked(value) : value
        Text(showUnit ? "\(text) \(format.unit.title)" : text)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(rial)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// A rounded progress bar that turns red once it passes 100%.
struct BudgetBar: View {
    let fraction: Double
    var color: Color = .accentColor
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.1))
                Capsule()
                    .fill(fraction > 1 ? Color.red : color)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.5), value: fraction)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraction * 100)) درصد"))
    }
}

/// One entry in a list: category badge, title, details and signed amount.
struct EntryRow: View {
    @Environment(AppSettings.self) private var settings
    let entry: LedgerEntry
    var showsDate = true

    var body: some View {
        let format = settings.format
        HStack(spacing: 12) {
            SymbolBadge(
                symbol: entry.kind == .transfer ? EntryKind.transfer.symbol : (entry.category?.symbol ?? "questionmark"),
                color: entry.kind == .transfer ? Palette.transfer : (entry.category?.color ?? .accentColor)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(details(format))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            AmountText(
                rial: entry.kind == .expense ? -entry.amount : entry.amount,
                signed: entry.kind != .transfer,
                maskable: true
            )
            .font(.subheadline.weight(.bold))
            .foregroundStyle(entry.kind == .income ? Palette.income : (entry.kind == .transfer ? Color.secondary : Color.primary))
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func details(_ format: DisplayFormat) -> String {
        var parts: [String] = []
        if entry.kind != .transfer, !entry.note.isEmpty, let name = entry.category?.name { parts.append(name) }
        if let account = entry.account?.name { parts.append(account) }
        parts.append(showsDate ? format.relativeDay(entry.date) : format.time(entry.date))
        return parts.joined(separator: " · ")
    }
}

/// Previous / title / next control for stepping through months or years.
struct PeriodStepper: View {
    let title: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("دوره قبل")
            Spacer()
            Text(title)
                .font(.headline)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.forward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("دوره بعد")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}
