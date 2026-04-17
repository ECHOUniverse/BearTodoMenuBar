import Foundation

struct TodoLine {
    let text: String
    let lineNumber: Int
}

struct TodoParser {
    static func parseUnchecked(from markdown: String) -> [TodoLine] {
        let pattern = "^[-*] \\[ \\] (.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }
        let matches = regex.matches(
            in: markdown,
            options: [],
            range: NSRange(location: 0, length: markdown.utf16.count)
        )
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: markdown) else { return nil }
            let lineRange = Range(match.range, in: markdown)!
            let prefix = String(markdown[..<lineRange.lowerBound])
            let lineNumber = prefix.components(separatedBy: .newlines).count
            return TodoLine(text: String(markdown[range]), lineNumber: lineNumber)
        }
    }
}
