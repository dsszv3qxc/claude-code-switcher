import Foundation

public enum SkillMetadataParser {
    public static func parse(_ text: String) -> SkillMetadata {
        let fields = frontmatterFields(in: text)

        return SkillMetadata(
            name: fields["name"],
            description: fields["description"] ?? "",
            allowedTools: fields["allowed-tools"],
            disallowedTools: fields["disallowed-tools"],
            disableModelInvocation: boolValue(fields["disable-model-invocation"])
        )
    }

    private static func frontmatterFields(in text: String) -> [String: String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return [:]
        }

        var fields: [String: String] = [:]

        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                break
            }

            guard let separator = line.firstIndex(of: ":") else {
                continue
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
            let valueStart = line.index(after: separator)
            let rawValue = String(line[valueStart...]).trimmingCharacters(in: .whitespacesAndNewlines)

            if !key.isEmpty {
                fields[key] = stripWrappingQuotes(rawValue)
            }
        }

        return fields
    }

    private static func stripWrappingQuotes(_ value: String) -> String {
        guard value.count >= 2 else {
            return value
        }

        let first = value.first
        let last = value.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }

        return value
    }

    private static func boolValue(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return ["true", "yes", "1"].contains(value.lowercased())
    }
}
