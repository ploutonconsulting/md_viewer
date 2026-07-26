# Architecture Decision Records

## ADR-001 — Use DocumentGroup for file handling

**Date:** 2026-05-13  
**Status:** Accepted

### Context
The app needs to open markdown files from Finder, the command line, and drag-and-drop. We could manage file access manually (NSOpenPanel + security-scoped bookmarks) or use the system-provided document model.

### Decision
Use `DocumentGroup` with `FileDocument`. The system handles sandboxed file access, recent documents, window titling, and the Open dialog automatically.

### Consequences
- No custom file picker code needed.
- App is strictly a viewer (no write path), so `FileDocument` conformance is minimal.
- Cannot hold multiple files open in a single window (one document per window), which is acceptable for a viewer.

---

## ADR-002 — Use swift-markdown-ui for rendering

**Date:** 2026-05-13  
**Status:** Accepted

### Context
We need rich markdown rendering: headings, code blocks, tables, task lists, images, inline styles. Options considered:
1. `AttributedString` with custom markdown parsing — limited, no tables or images.
2. `WKWebView` rendering HTML — heavyweight, non-native look, sandboxing complexity.
3. `swift-markdown-ui` — pure SwiftUI, GFM-compliant via cmark-gfm, actively maintained.

### Decision
Use `swift-markdown-ui`. It provides composable, styleable SwiftUI views backed by cmark-gfm.

### Consequences
- GFM (GitHub Flavoured Markdown) is fully supported.
- Theming is built-in (GitHub, DocC, Basic themes available out of the box).
- Adds a package dependency; cmark-gfm is a C library compiled as part of the package.

---

## ADR-003 — Read-only viewer, no editing

**Date:** 2026-05-13  
**Status:** Accepted

### Context
The product brief is a *viewer*, not an editor. Adding write support introduces complexity (dirty state, conflict resolution, file coordination) that is out of scope.

### Decision
`MarkdownDocument.writableContentTypes` is empty. `fileWrapper(configuration:)` throws immediately. The New Item command is hidden.

### Consequences
- Users cannot accidentally modify files.
- Future editing support would require a significant rework of the document model and entitlements.

---

## ADR-004 — Per-document preferences via @AppStorage

**Date:** 2026-05-13  
**Status:** Accepted

### Context
Font size and theme are display preferences. They could be:
1. Per-document (stored in the file or alongside it) — complex, modifies nothing.
2. Global (single UserDefaults value) — simple, applies to all windows.

### Decision
Use `@AppStorage` with a single global key. All windows share the same font size and theme preference.

### Consequences
- Preferences persist across launches automatically.
- All open documents share the same display settings (acceptable for a viewer).
- No per-document customisation (could be revisited later).

---

## ADR-005 — Search as line filter, not highlight

**Date:** 2026-05-13  
**Status:** Accepted

### Context
Users need to locate content in large markdown files. Options:
1. Highlight matching text in place.
2. Filter: show only lines containing the search term.

### Decision
Filter approach — split document by newline, keep only lines matching the search term. Simple to implement, works well for structured documents.

### Consequences
- Context around matches is lost (user sees only matching lines).
- No match count or navigation between matches.
- Implementation is ~5 lines of code.
- Can be upgraded to in-place highlighting later if needed.

---

## ADR-006 — Evaluated mdxg as a rendering dependency

**Date:** 2026-05-28  
**Status:** Not adopted — use as design reference only

### Context
[mdxg](https://github.com/vercel-labs/mdxg) is a specification and TypeScript reference implementation that defines how markdown viewers should present and navigate documents. Features it standardises: virtual page splitting of long documents, prev/next page navigation, document-level outline/TOC, search, theming, and editor/viewer mode toggles.

We evaluated it as a potential dependency or design reference for md_viewer.

### Decision
Do not adopt as a dependency. The repo is 94% TypeScript with no Swift package. It cannot be imported into a native macOS SwiftUI app.

Use the **spec as a design reference** for future UX work, particularly:

- **Virtual paging** — split long documents at `##` heading boundaries and expose prev/next navigation. `DocumentSection.parsedSections()` already performs the split; adding a `currentPageIndex: Int` state and navigation controls in `ContentView` is the only remaining work.
- **Page outline** — the sidebar already satisfies this part of the spec.
- **Search** — partially satisfies the spec (line filter today; in-place highlighting is the gap).

### Consequences
- No new dependency introduced.
- Paged navigation is a well-scoped future feature: state change in `ContentView`, two toolbar buttons, no new parsing logic needed.
- Full mdxg spec conformance is achievable natively with ~1–2 focused sessions of work.

---

## ADR-007 — Render YAML frontmatter as a metadata table

**Date:** 2026-07-26  
**Status:** Accepted

### Context
A document opening with a YAML frontmatter block (`---` ... `---`) was rendered as document
content instead of metadata: `swift-markdown-ui` has no frontmatter concept, so the opening
fence parses as a CommonMark thematic break and the block itself parses as a setext H2 (see
Issue #11). Options considered:
1. Render the frontmatter as a key/value table above the document body.
2. Add a View-menu toggle to suppress frontmatter rendering entirely.

### Decision
Strip frontmatter from the document before it reaches `parsedSections()` / `MarkdownUI`, and
render it as a dedicated SwiftUI key/value table (`FrontmatterTableView`) above the body in
Preview mode. Values render through `Text`, never through `Markdown`, so Markdown syntax inside
a value is shown verbatim rather than interpreted. The suppression-toggle alternative was not
built — a table communicates the metadata rather than hiding it.

The parser (`FrontmatterParser`) is a minimal line scanner scoped to the shapes observed in a
176-document corpus survey (scalar, empty-value, block-sequence, and inline-flow-sequence keys),
not a YAML engine — no new package dependency. A validation gate rejects any fenced block that
isn't YAML-shaped, so a document that opens with a stylistic `---` divider is left untouched:
`split` returns `nil` and the body is the byte-identical original input.

### Consequences
- Raw mode is unaffected — it stays byte-verbatim, fences included, by design.
- Nested mappings, `|`/`>` block scalars, and YAML comments are out of scope; a block scalar
  degrades to a literal `|` value rather than crashing.
- No frontmatter support in the PDF export pipeline yet — revisit at integration time with
  `feature/pdf-export`.
