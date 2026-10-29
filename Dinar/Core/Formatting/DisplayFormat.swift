import Foundation

/// Everything needed to turn stored values into Persian text, derived from user settings.
struct DisplayFormat: Equatable, Sendable {
    var unit: CurrencyUnit = .toman
    var persianDigits: Bool = true
    var hideAmounts: Bool = false

    var locale: Locale {
        Locale(identifier: persianDigits ? "fa_IR" : "fa_IR@numbers=latn")
    }

    // MARK: Numbers

    func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    func percent(_ fraction: Double) -> String {
        number(Int((fraction * 100).rounded())) + "٪"
    }

    /// «۴۸٬۲۵۰٬۰۰۰» in the chosen unit.
    func amount(_ rial: Int64) -> String {
        let value = rial / unit.rialFactor
        let text = abs(value).formatted(.number.grouping(.automatic).locale(locale))
        return value < 0 ? isolate("−" + text) : text
    }

    /// Same as `amount` with an explicit sign, kept left-to-right inside RTL text.
    func signed(_ rial: Int64) -> String {
        let body = amount(abs(rial))
        switch rial {
        case let x where x > 0: return isolate("+" + body)
        case let x where x < 0: return isolate("−" + body)
        default: return body
        }
    }

    /// Short form for charts: «۱۸٫۴ میلیون».
    func compact(_ rial: Int64) -> String {
        let value = Double(abs(rial / unit.rialFactor))
        let sign = rial < 0 ? "−" : ""
        let (scaled, suffix): (Double, String) = switch value {
        case 1_000_000_000...: (value / 1_000_000_000, " میلیارد")
        case 1_000_000...: (value / 1_000_000, " میلیون")
        case 1_000...: (value / 1_000, " هزار")
        default: (value, "")
        }
        let text = scaled.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return sign + text + suffix
    }

    /// Masks the value when the user chose to hide amounts.
    func masked(_ text: String) -> String { hideAmounts ? "••••••" : text }

    /// Parses digits typed in the display unit (Persian or Latin) into rial.
    func rial(fromInput input: String) -> Int64? {
        let latin = input.latinDigits.filter(\.isNumber)
        guard !latin.isEmpty, let value = Int64(latin) else { return nil }
        return value * unit.rialFactor
    }

    // MARK: Dates

    private func formatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Jalali.calendar
        formatter.locale = locale
        formatter.dateFormat = template
        return formatter
    }

    /// «۲۶ مهر ۱۴۰۵»
    func fullDate(_ date: Date) -> String { formatter("d MMMM y").string(from: date) }

    /// «۲۶ مهر»
    func dayMonth(_ date: Date) -> String { formatter("d MMMM").string(from: date) }

    /// «مهر ۱۴۰۵»
    func monthYear(_ date: Date) -> String { formatter("MMMM y").string(from: date) }

    /// «مهر»
    func monthName(_ date: Date) -> String { formatter("MMMM").string(from: date) }

    /// «۱۴۰۵»
    func year(_ date: Date) -> String { formatter("y").string(from: date) }

    /// «شنبه ۲۶ مهر»
    func weekdayDayMonth(_ date: Date) -> String { formatter("EEEE d MMMM").string(from: date) }

    func time(_ date: Date) -> String { formatter("HH:mm").string(from: date) }

    /// «امروز»، «دیروز» or a date.
    func relativeDay(_ date: Date, now: Date = .now) -> String {
        let calendar = Jalali.calendar
        if calendar.isDate(date, inSameDayAs: now) { return "امروز" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "دیروز" }
        return calendar.isDate(date, equalTo: now, toGranularity: .year) ? dayMonth(date) : fullDate(date)
    }

    /// Wraps text in a left-to-right isolate so signs stay next to the digits in RTL layouts.
    private func isolate(_ text: String) -> String { "\u{2066}" + text + "\u{2069}" }
}

extension String {
    /// Converts Persian and Arabic-Indic digits to ASCII digits.
    var latinDigits: String {
        let persian = Array("۰۱۲۳۴۵۶۷۸۹")
        let arabic = Array("٠١٢٣٤٥٦٧٨٩")
        return String(map { char in
            if let i = persian.firstIndex(of: char) { return Character(String(i)) }
            if let i = arabic.firstIndex(of: char) { return Character(String(i)) }
            return char
        })
    }

    var persianDigits: String {
        let persian = Array("۰۱۲۳۴۵۶۷۸۹")
        return String(map { char in
            if let value = char.wholeNumberValue, char.isASCII { return persian[value] }
            return char
        })
    }
}
