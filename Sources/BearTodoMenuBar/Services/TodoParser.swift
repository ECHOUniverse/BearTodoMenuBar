import Foundation

enum TodoParser {
    static func parseAllTodos(from markdown: String) -> [TodoLine] {
        let unchecked = parseLines(matching: "^[-*] \\[ \\] (.+)$", in: markdown, isCompleted: false)
        let checked = parseLines(matching: "^[-*] \\[[xX]\\] (.+)$", in: markdown, isCompleted: true)
        return (unchecked + checked).sorted { $0.lineNumber < $1.lineNumber }
    }

    private static func parseLines(matching pattern: String, in markdown: String, isCompleted: Bool) -> [TodoLine] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        return regex.matches(in: markdown, range: NSRange(location: 0, length: markdown.utf16.count)).compactMap { match in
            guard let range = Range(match.range(at: 1), in: markdown),
                  let lineRange = Range(match.range, in: markdown) else { return nil }
            return TodoLine(text: String(markdown[range]),
                            lineNumber: String(markdown[..<lineRange.lowerBound]).components(separatedBy: .newlines).count,
                            isCompleted: isCompleted)
        }
    }
}
