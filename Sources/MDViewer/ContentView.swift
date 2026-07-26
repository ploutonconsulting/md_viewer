import SwiftUI
import MarkdownUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @AppStorage(FontSizePreferences.storageKey, store: FontSizePreferences.userDefaults)
    private var fontSize = FontSizePreferences.defaultSize
    @AppStorage("format") private var formatView: String = Format.preview.rawValue
    @AppStorage("lineSpacing") private var lineSpacingRaw: String = LineSpacing.normal.rawValue
    @State private var searchText = ""
    @State private var selectedSectionID: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    // Split once when the view value is created, not once per consumer:
    // as a computed property this re-parsed the whole document on every
    // read, several times per render pass.
    private let frontmatter: Frontmatter?
    private let documentBody: String

    init(document: MarkdownDocument, fileURL: URL?) {
        self.document = document
        self.fileURL = fileURL
        let split = FrontmatterParser.split(document.text)
        self.frontmatter = split.frontmatter
        self.documentBody = split.body
    }

    private var sections: [DocumentSection] {
        documentBody.parsedSections()
    }

    var body: some View {
        NavigationSplitView {
            OutlineSidebarView(sections: sections, selectedSectionID: $selectedSectionID)
        } detail: {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 0) {
                        pageCard
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 24)
                }
                .background(Color(NSColor.underPageBackgroundColor))
                .onChange(of: selectedSectionID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            StatusBar(fileURL: fileURL)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { fontSize = FontSizePreferences.decreased(fontSize) } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease Text Size")
                .disabled(!FontSizePreferences.canDecrease(fontSize))

                Button { fontSize = FontSizePreferences.increased(fontSize) } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase Text Size")
                .disabled(!FontSizePreferences.canIncrease(fontSize))

                Divider()

                Picker("Format", selection: $formatView) {
                    ForEach(Format.allCases) { t in
                        Text(t.label).tag(t.rawValue)
                    }
                }
                .pickerStyle(.inline)

                Picker("Line Spacing", selection: $lineSpacingRaw) {
                    ForEach(LineSpacing.allCases) { s in
                        Text(s.label).tag(s.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .help("Line Spacing")

                ShareLink(item: document.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share")
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Find")
        .onAppear {
            fontSize = FontSizePreferences.clamped(fontSize)
        }
    }

    // Extracted to help the compiler type-check the body
    private var pageCard: some View {
        cardContent
            .padding(40)
            .background(pageColor)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
            .frame(maxWidth: 820)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch currentFormat {
        case .raw:
            rawContent
        case .preview:
            // The table sits outside sectionedContent's own VStack, with the
            // same 28pt gap used between rendered sections, so it reads as a
            // fixed document header rather than page content.
            VStack(alignment: .leading, spacing: 28) {
                if let frontmatter, !frontmatter.isEmpty {
                    FrontmatterTableView(frontmatter: frontmatter, fontSize: fontSize)
                }
                if searchText.isEmpty {
                    sectionedContent
                } else {
                    Markdown(filteredText)
                        .modifier(PreviewMarkdownStyle(fontSize: fontSize,
                                                       lineSpacingEm: currentLineSpacing.em))
                }
            }
        }
    }

    // Verbatim source, monospaced. Theme is intentionally inert here;
    // font size and the line filter still apply.
    private var rawContent: some View {
        Text(rawSource)
            .font(.system(size: fontSize, design: .monospaced))
            .textSelection(.enabled)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Raw mode is byte-verbatim source, so its filter runs over the whole
    // document — frontmatter lines included. Only the preview filter works
    // off the body.
    private var rawSource: String {
        searchText.isEmpty ? document.text : matchingLines(in: document.text)
    }

    @ViewBuilder
    private var sectionedContent: some View {
        // A frontmatter-only document has an empty body: suppress
        // DocumentSection's whole-document fallback so it doesn't draw a
        // blank section card below the table.
        if documentBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyView()
        } else {
            // Gap between rendered sections so headings don't butt against
            // the previous section's trailing content.
            VStack(alignment: .leading, spacing: 28) {
                ForEach(sections) { section in
                    Markdown(section.content)
                        .modifier(PreviewMarkdownStyle(fontSize: fontSize,
                                                       lineSpacingEm: currentLineSpacing.em))
                        .id(section.id)
                }
            }
        }
    }

    private var filteredText: String {
        matchingLines(in: documentBody)
    }

    private func matchingLines(in text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .joined(separator: "\n")
    }

    private var currentFormat: Format {
        Format(rawValue: formatView) ?? .preview
    }

    private var currentLineSpacing: LineSpacing {
        LineSpacing(rawValue: lineSpacingRaw) ?? .normal
    }

    private var pageColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : .white
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.15)
    }
}

// Shared styling for the rendered (preview) Markdown. There is no
// user-selectable theme: rendering uses MarkdownUI's default style with the
// paragraph block overridden so the line-spacing presets take effect.
private struct PreviewMarkdownStyle: ViewModifier {
    let fontSize: Double
    let lineSpacingEm: CGFloat

    func body(content: Content) -> some View {
        content
            .markdownTextStyle { FontSize(fontSize) }
            .markdownBlockStyle(\.paragraph) { configuration in
                configuration.label
                    .fixedSize(horizontal: false, vertical: true)
                    .relativeLineSpacing(.em(lineSpacingEm))
                    .markdownMargin(top: .zero, bottom: .em(1))
            }
            .textSelection(.enabled)
    }
}

private struct StatusBar: View {
    let fileURL: URL?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(fileURL?.path(percentEncoded: false) ?? "—")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}
