import Foundation
import Testing
@testable import TallyShotCore

private func values(_ text: String) -> [Decimal] {
    AmountParser.amounts(in: text).map(\.value)
}

private func dec(_ s: String) -> Decimal { Decimal(string: s)! }

@Suite struct AmountParserTests {
    @Test(arguments: [
        ("45.20", "45.20"),
        ("$45.20", "45.20"),
        ("1,234.56", "1234.56"),
        ("$12,345,678.90", "12345678.90"),
        ("A$ 99.95", "99.95"),
        ("AUD 10.00", "10.00"),
        ("+3.50", "3.50"),
        ("12.50 CR", "12.50"),
        ("€7", "7"),
    ])
    func positives(text: String, expected: String) {
        #expect(values(text) == [dec(expected)])
    }

    @Test(arguments: [
        "-45.20", "-$45.20", "$-45.20", "($45.20)", "(45.20)", "45.20-", "45.20 DR", "45.20Dr", "\u{2212}45.20",
    ])
    func negatives(text: String) {
        #expect(values(text) == [dec("-45.20")])
    }

    @Test func unbalancedParenthesisIsNotNegative() {
        #expect(values("(45.20") == [dec("45.20")])
    }

    @Test(arguments: ["12/03/2026", "2026-03-12", "10:30", "15%", "INV2045", "AB12", "45.00-50.00"])
    func ignoresNonAmounts(text: String) {
        #expect(values(text).isEmpty)
    }

    @Test func trailingMinusAtEndOfLine() {
        #expect(values("Fee 3.00-") == [dec("-3.00")])
    }

    @Test func europeanDecimalCommaIsRejectedNotMisread() {
        #expect(values("1234,56").isEmpty)
    }

    @Test func findsEveryAmountInARowInOrder() {
        let text = "12/03/2026  Woolworths 1234  -$45.20  $1,020.00"
        #expect(values(text) == [dec("1234"), dec("-45.20"), dec("1020.00")])
    }

    @Test func rangeCoversSignCurrencyAndMarker() {
        let text = "Paid (A$12.00) and 5.00 DR"
        let found = AmountParser.amounts(in: text).map { String(text[$0.range]) }
        #expect(found == ["(A$12.00)", "5.00 DR"])
    }

    @Test func fractionDigitsComeFromTheToken() {
        #expect(AmountParser.amounts(in: "3 4.5 6.789").map(\.fractionDigits) == [0, 1, 3])
    }
}
