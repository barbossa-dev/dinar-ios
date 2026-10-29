import Foundation
import SwiftData
import Testing
@testable import Dinar

@MainActor
struct DisplayFormatTests {
    @Test func amountUsesPersianDigitsAndToman() {
        let format = DisplayFormat(unit: .toman, persianDigits: true)
        #expect(format.amount(482_500_000) == "۴۸٬۲۵۰٬۰۰۰")
    }

    @Test func amountCanUseLatinDigits() {
        let format = DisplayFormat(unit: .rial, persianDigits: false)
        #expect(format.amount(1_250).latinDigits.filter(\.isNumber) == "1250")
        #expect(!format.amount(1_250).contains { "۰۱۲۳۴۵۶۷۸۹".contains($0) })
    }

    @Test func inputParsingAcceptsPersianDigits() {
        let format = DisplayFormat(unit: .toman)
        #expect(format.rial(fromInput: "۸۵۰٬۰۰۰") == 8_500_000)
        #expect(format.rial(fromInput: "") == nil)
    }

    @Test func jalaliMonthOfKnownDate() throws {
        // 18 October 2026 is 26 Mehr 1405.
        let date = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12)))
        #expect(Jalali.year(of: date) == 1405)
        #expect(Jalali.month(of: date) == 7)
        #expect(DisplayFormat().fullDate(date) == "۲۶ مهر ۱۴۰۵")
    }
}

@MainActor
struct EntryEditorModelTests {
    @Test func keypadIgnoresLeadingZeroAndCapsLength() {
        let model = EntryEditorModel(request: .new(.expense), unit: .toman)
        model.append("0")
        #expect(model.digits.isEmpty)
        model.append("5")
        model.appendThousands()
        #expect(model.digits == "5000")
        model.backspace()
        #expect(model.digits == "500")
        #expect(model.amount(in: .toman) == 5_000)
    }

    @Test func changingKindClearsCategory() throws {
        let container = try ModelContainer(
            for: Account.self, LedgerCategory.self, LedgerEntry.self, Budget.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let category = LedgerCategory(name: "خوراک", kind: .expense, symbol: "cart", colorHex: "000000", sortOrder: 0)
        container.mainContext.insert(category)
        let model = EntryEditorModel(request: .new(.expense), unit: .toman)
        model.category = category
        model.kind = .income
        #expect(model.category == nil)
    }

    @Test func validationRequiresAmount() {
        let model = EntryEditorModel(request: .new(.expense), unit: .toman)
        #expect(model.validationMessage(unit: .toman) == "مبلغ را وارد کنید")
    }
}
