import Foundation

struct TodoLine {
    let text: String
    let lineNumber: Int
    let isCompleted: Bool
}

struct TodoParser {
    /// Returns all checkbox lines (checked + unchecked), sorted by line number.
    static func parseAllTodos(from markdown: String) -> [TodoLine] {
        let unchecked = parseLines(matching: "^[-*] \\[ \\] (.+)$", in: markdown, isCompleted: false)
        let checked   = parseLines(matching: "^[-*] \\[[xX]\\] (.+)$", in: markdown, isCompleted: true)
        return (unchecked + checked).sorted { $0.lineNumber < $1.lineNumber }
    }

    /// Convenience: unchecked-only (backwards compatible).
    static func parseUnchecked(from markdown: String) -> [TodoLine] {
        parseAllTodos(from: markdown).filter { !$0.isCompleted }
    }

    // MARK: - Private

    private static func parseLines(matching pattern: String, in markdown: String, isCompleted: Bool) -> [TodoLine] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }
        let matches = regex.matches(
            in: markdown,
            options: [],
            range: NSRange(location: 0, length: markdown.utf16.count)
        )
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: markdown),
                  let lineRange = Range(match.range, in: markdown)
            else { return nil }
            let prefix = String(markdown[..<lineRange.lowerBound])
            let lineNumber = prefix.components(separatedBy: .newlines).count
            return TodoLine(text: String(markdown[range]), lineNumber: lineNumber, isCompleted: isCompleted)
        }
    }
}
