import SwiftUI

extension String {
    func highlighted(query: String, base: Font = .body, highlightColor: Color = .primary) -> Text {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Text(self).font(base)
        }

        let lowercased = self.lowercased()
        let lowercasedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        var result = Text("")
        var searchStart = lowercased.startIndex

        while searchStart < lowercased.endIndex {
            guard let range = lowercased.range(of: lowercasedQuery, range: searchStart..<lowercased.endIndex) else {
                let remaining = String(self[searchStart...])
                result = result + Text(remaining).font(base).foregroundStyle(.secondary)
                break
            }

            let before = String(self[searchStart..<range.lowerBound])
            if !before.isEmpty {
                result = result + Text(before).font(base).foregroundStyle(.secondary)
            }

            let match = String(self[range])
            result = result + Text(match).font(base).bold().foregroundStyle(highlightColor)

            searchStart = range.upperBound
        }

        return result
    }
}
