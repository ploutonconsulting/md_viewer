import SwiftUI

// A subdued key/value properties block for a document's YAML frontmatter.
// Values render through Text — never through Markdown — so syntax inside a
// value (e.g. `**bold**`) is shown verbatim, not interpreted. No header row:
// a "Key | Value" label would add noise to what is visually a properties
// block, not content.
struct FrontmatterTableView: View {
    let frontmatter: Frontmatter
    let fontSize: Double

    private let keyColumnWidth: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(frontmatter.entries.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Divider()
                }
                row(for: entry)
            }
        }
    }

    private func row(for entry: FrontmatterEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.key)
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(width: keyColumnWidth, alignment: .trailing)

            Text(entry.value)
                .font(.system(size: fontSize))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 6)
    }
}
