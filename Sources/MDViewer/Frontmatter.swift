import Foundation

struct FrontmatterEntry: Identifiable {
    let id: Int          // document order
    let key: String
    let value: String    // display-ready: unquoted, flattened, verbatim text
}

struct Frontmatter {
    let entries: [FrontmatterEntry]
    var isEmpty: Bool { entries.isEmpty }
}

enum FrontmatterParser {
    /// Splits a document into its frontmatter and body.
    /// Returns nil frontmatter when absent, unterminated, or failing the §4 validation gate;
    /// in every nil case `body` is the unmodified input.
    static func split(_ text: String) -> (frontmatter: Frontmatter?, body: String) {
        let normalizedText = normalized(text)
        let lines = normalizedText.components(separatedBy: "\n")

        guard let firstLine = lines.first,
              firstLine.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return (nil, text)
        }

        guard let closingIndex = closingFenceIndex(in: lines) else {
            return (nil, text)
        }

        let blockLines = Array(lines[1..<closingIndex])
        let body = lines[(closingIndex + 1)...].joined(separator: "\n")

        // A block with no non-blank lines is valid, empty frontmatter: the
        // fences are stripped from the body but no table is rendered.
        let nonBlankLines = blockLines.filter { !isBlank($0) }
        guard !nonBlankLines.isEmpty else {
            return (Frontmatter(entries: []), body)
        }

        guard let entries = extractEntries(from: blockLines) else {
            return (nil, text)
        }

        return (Frontmatter(entries: entries), body)
    }

    // MARK: - Fence detection

    private static func closingFenceIndex(in lines: [String]) -> Int? {
        guard lines.count > 1 else { return nil }
        for index in 1..<lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "..." {
                return index
            }
        }
        return nil
    }

    // MARK: - Validation gate + extraction

    /// Validates the §4 gate and extracts key/value entries in the same pass.
    /// Returns nil the moment any line fails to match an allowed shape, or if
    /// no key line was found at all.
    private static func extractEntries(from blockLines: [String]) -> [FrontmatterEntry]? {
        var entries: [FrontmatterEntry] = []
        var sawKeyLine = false
        var index = 0

        while index < blockLines.count {
            let line = blockLines[index]
            if isBlank(line) {
                index += 1
                continue
            }

            if isIndented(line) {
                // Any indented non-blank line is a valid continuation shape per the gate.
                index += 1
                continue
            }

            guard let colon = line.firstIndex(of: ":") else {
                return nil
            }

            // YAML block mappings require ':' to be followed by whitespace or end-of-line.
            let afterColonIndex = line.index(after: colon)
            if afterColonIndex < line.endIndex {
                let afterColon = line[afterColonIndex]
                guard afterColon == " " || afterColon == "\t" else {
                    return nil
                }
            }

            let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                return nil
            }
            sawKeyLine = true

            var value = String(line[afterColonIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Gather indented lines that belong to this key, up to the next
            // unindented line.
            var listItems: [String] = []
            var lookahead = index + 1
            while lookahead < blockLines.count {
                let next = blockLines[lookahead]
                if isBlank(next) {
                    lookahead += 1
                    continue
                }
                guard isIndented(next) else { break }
                if isBlockSequenceItem(next) {
                    listItems.append(sequenceItemValue(next))
                }
                // Non-sequence indented continuation lines (e.g. a `|`
                // block scalar body) are valid per the gate but ignored
                // during extraction — a documented degradation.
                lookahead += 1
            }

            if value.isEmpty, !listItems.isEmpty {
                value = listItems.joined(separator: ", ")
            } else if let inline = inlineListValue(value) {
                value = inline
            } else {
                value = stripQuotes(value)
            }

            entries.append(FrontmatterEntry(id: entries.count, key: key, value: value))
            index = lookahead
        }

        return sawKeyLine ? entries : nil
    }

    // MARK: - Line shape helpers

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func isIndented(_ line: String) -> Bool {
        guard let first = line.first else { return false }
        return first == " " || first == "\t"
    }

    private static func isBlockSequenceItem(_ line: String) -> Bool {
        guard isIndented(line) else { return false }
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("-") else { return false }
        let afterDash = trimmed.dropFirst()
        return afterDash.isEmpty || afterDash.first == " "
    }

    private static func isIndentedContinuation(_ line: String) -> Bool {
        isIndented(line) && !isBlank(line)
    }

    private static func sequenceItemValue(_ line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("-") {
            trimmed.removeFirst()
        }
        return stripQuotes(trimmed.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Value shaping

    private static func inlineListValue(_ value: String) -> String? {
        guard value.hasPrefix("["), value.hasSuffix("]") else { return nil }
        let inner = value.dropFirst().dropLast()
        let items = inner
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { stripQuotes($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return items.joined(separator: ", ")
    }

    private static func stripQuotes(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, let last = value.last,
              first == last, first == "\"" || first == "'" else {
            return value
        }
        return String(value.dropFirst().dropLast())
    }

    // MARK: - Normalization

    /// Normalizes CRLF and lone CR to LF, and strips a leading BOM, so the
    /// scanner never sees a stray `\r`.
    private static func normalized(_ text: String) -> String {
        var result = text
        if result.hasPrefix("\u{FEFF}") {
            result.removeFirst()
        }
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        return result
    }
}
