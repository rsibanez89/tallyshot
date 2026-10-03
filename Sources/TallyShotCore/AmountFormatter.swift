import Foundation

public enum AmountFormatter {
    /// For reading: "-1,234.50".
    public static func display(_ value: Decimal, fractionDigits: Int) -> String {
        format(value, fractionDigits: fractionDigits, grouping: true)
    }

    /// For pasting into spreadsheets and calculators: "-1234.50".
    public static func plain(_ value: Decimal, fractionDigits: Int) -> String {
        format(value, fractionDigits: fractionDigits, grouping: false)
    }

    private static func format(_ value: Decimal, fractionDigits: Int, grouping: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = "."
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = grouping
        formatter.minusSign = "-"
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
