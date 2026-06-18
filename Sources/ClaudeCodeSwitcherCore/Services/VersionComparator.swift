import Foundation

public enum VersionComparator {
    public static func isVersion(_ current: String, olderThan latest: String) -> Bool {
        compare(current, latest) == .orderedAscending
    }

    public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(from: lhs)
        let right = components(from: rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0

            if leftValue < rightValue {
                return .orderedAscending
            }

            if leftValue > rightValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    public static func firstVersion(in text: String) -> String? {
        let pattern = #"\d+(?:\.\d+){1,3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let swiftRange = Range(match.range, in: text) else {
            return nil
        }

        return String(text[swiftRange])
    }

    private static func components(from version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

