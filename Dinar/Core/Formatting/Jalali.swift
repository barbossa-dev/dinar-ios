import Foundation

/// Helpers around the Solar Hijri (Persian) calendar, which Foundation supports natively.
enum Jalali {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .persian)
        calendar.locale = Locale(identifier: "fa_IR")
        calendar.timeZone = .current
        calendar.firstWeekday = 7 // Saturday
        return calendar
    }

    static func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    static func yearInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 0)
    }

    static func adding(months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: date) ?? date
    }

    static func month(of date: Date) -> Int { calendar.component(.month, from: date) }
    static func year(of date: Date) -> Int { calendar.component(.year, from: date) }

    /// Days remaining in the month of `date`, including that day.
    static func daysLeftInMonth(from date: Date) -> Int {
        let interval = monthInterval(containing: date)
        let start = calendar.startOfDay(for: date)
        return max(1, calendar.dateComponents([.day], from: start, to: interval.end).day ?? 1)
    }

    static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, equalTo: b, toGranularity: .month)
    }
}
