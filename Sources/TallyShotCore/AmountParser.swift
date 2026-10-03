import Foundation

/// A number read from text, with bank-statement sign conventions applied.
public struct Amount: Equatable, Sendable {
    public let value: Decimal
    public let fractionDigits: Int
    /// The whole token in the source text, including sign, currency and CR/DR marker.
    public let range: Range<String.Index>
}

/// Finds numbers in a line of text.
///
/// Assumes "," groups thousands and "." marks decimals (en-AU, en-US).
/// Tokens touching letters, "/", ":", "%" or a digit-hyphen-digit run are skipped,
/// so dates, times, percentages and IDs are ignored.
/// Negative forms: "-45", "-$45", "$-45", "(45)", "45-", "45 DR".
public enum AmountParser {
    public static func amounts(in text: String) -> [Amount] {
        let whole = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: whole).compactMap { amount(from: $0, in: text) }
    }

    private static let minusSigns: Set<String> = ["-", "\u{2212}"]

    private static let pattern = try! NSRegularExpression(pattern: #"""
        (?<! [\p{L}\p{N}/:.,] | \d- )
        (?<open>\()?
        (?<sign>[-+\x{2212}])?
        (?: (?:AUD|USD|NZD|EUR|GBP|A|US|NZ)?\s?[$€£¥]\s? | (?:AUD|USD|NZD|EUR|GBP)\s )?
        (?<sign2>[-\x{2212}])?
        (?<number> \d{1,3}(?:,\d{3})+(?:\.\d+)? | \d+(?:\.\d+)? )
        (?<close>\))?
        (?<trail>[-\x{2212}](?!\d))?
        (?: \s?(?<marker>CR|DR|Cr|Dr)(?!\p{L}) )?
        (?! [\p{L}\p{N}/:%] | [-.,]\d )
        """#, options: [.allowCommentsAndWhitespace])

    private static func amount(from match: NSTextCheckingResult, in text: String) -> Amount? {
        func group(_ name: String) -> String? {
            Range(match.range(withName: name), in: text).map { String(text[$0]) }
        }
        guard let number = group("number"),
              let range = Range(match.range, in: text),
              let magnitude = Decimal(string: number.replacingOccurrences(of: ",", with: ""),
                                      locale: Locale(identifier: "en_US_POSIX"))
        else { return nil }

        let hasMinus = [group("sign"), group("sign2"), group("trail")]
            .contains { $0.map(minusSigns.contains) ?? false }
        let hasParens = group("open") != nil && group("close") != nil
        let isDebit = group("marker")?.uppercased() == "DR"
        let isNegative = hasMinus || hasParens || isDebit

        let fractionDigits = number.split(separator: ".").dropFirst().first?.count ?? 0
        return Amount(value: isNegative ? -magnitude : magnitude, fractionDigits: fractionDigits, range: range)
    }
}
