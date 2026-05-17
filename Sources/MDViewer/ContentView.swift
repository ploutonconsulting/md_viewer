import SwiftUI
import MarkdownUI

struct ContentView: View {
    let document: MarkdownDocument
    let fileURL: URL?

    @AppStorage(FontSizePreferences.storageKey, store: FontSizePreferences.userDefaults)
    private var fontSize = FontSizePreferences.defaultSize
    @AppStorage("theme") private var themeRaw: String = Theme.gitHub.rawValue
    @State private var searchText = ""
    @State private var selectedSectionID: Int? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var sections: [DocumentSection] {
        document.text.parsedSections()
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

                Picker("Theme", selection: $themeRaw) {
                    ForEach(Theme.allCases) { t in
                        Text(t.label).tag(t.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .help("Select Theme")

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
    @ViewBuilder
    private var pageCard: some View {
        if searchText.isEmpty {
            sectionedContent
                .padding(40)
                .background(pageColor)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
                .frame(maxWidth: 820)
        } else {
            Markdown(filteredText)
                .markdownTheme(currentTheme.markdownTheme)
                .markdownTextStyle { FontSize(fontSize) }
                .textSelection(.enabled)
                .padding(40)
                .background(pageColor)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .shadow(color: shadowColor, radius: 8, x: 0, y: 2)
                .frame(maxWidth: 820)
        }
    }

    private var sectionedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                Markdown(section.content)
                    .markdownTheme(currentTheme.markdownTheme)
                    .markdownTextStyle { FontSize(fontSize) }
                    .textSelection(.enabled)
                    .id(section.id)
            }
        }
    }

    private var filteredText: String {
        document.text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { $0.localizedCaseInsensitiveContains(searchText) }
            .joined(separator: "\n")
    }

    private var currentTheme: Theme {
        Theme(rawValue: themeRaw) ?? .gitHub
    }

    private var pageColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : .white
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.15)
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
