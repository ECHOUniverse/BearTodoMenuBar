import Foundation

struct TodoParser {
    static func parseUnchecked(from markdown: String) -> [String] {
        let pattern = "^- \\[ \\] (.+)$"
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
            return String(markdown[range])
        }
    }
}
