import Foundation

public enum DiagnosticRedactor {
    public static func redact(_ text: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        var value = text
        if let home = environment["HOME"], !home.isEmpty {
            value = value.replacingOccurrences(of: home, with: "<HOME>")
        }
        let patterns = [
            #"(?i)(authorization:\s*)([^\r\n]+)"#,
            #"(?i)((?:api[_-]?key|token|password)\s*[=:]\s*)([^\s,;]+)"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(value.startIndex..., in: value)
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: "$1<REDACTED>")
        }
        return value
    }
}

