# [#11] YAML frontmatter interpretation incorrect — development specification

**Source:** https://github.com/pierreoosthuizen/md_viewer/issues/11 · **Author:** scroll · **Date:** 2026-07-26
**Status:** panel-reviewed (T2, 2 reviewers; all findings folded in)
**Branch:** `bugfix/11-yaml-frontmatter-rendering` (off `development` @ `b952d3a`)

## 1. Summary & intent

Opening a Markdown document that begins with a YAML frontmatter block renders the block as
document content instead of metadata. The reporter asks for the frontmatter to be rendered as
a table, or for a switch to suppress it. **Decision taken by Pierre (2026-07-26): render it as
a key/value table at the top of the rendered document.** The toggle alternative is not built.

**Acceptance criteria:**
- [ ] A document whose first line is `---`, which has a closing `---`/`...` fence, and whose
      enclosed block is YAML-shaped (§4 validation gate), renders that block as a key/value
      table above the document body, in Preview mode.
- [ ] The frontmatter block no longer renders as a horizontal rule + setext H2 in Preview mode.
- [ ] Frontmatter values are displayed verbatim as plain text — Markdown syntax inside a value
      (e.g. `title: **bold**`) is not interpreted.
- [ ] Raw mode still shows the document byte-for-byte, frontmatter fences included.
- [ ] A document with no frontmatter renders exactly as it does today, with no empty table.
- [ ] **No document loses content.** An unterminated fence, or a fence-bounded block that is
      not YAML-shaped, is treated as *not* frontmatter and renders as it does today.
- [ ] The outline sidebar is unchanged: frontmatter contributes no entry, and clicking a
      heading still scrolls to the correct section on a frontmatter-bearing document.
- [ ] Unit tests covering §6 pass via `xcodebuild test`.

## 2. Classification

- **Kind:** defect
- **Layer/owner:** presentation layer of this repo — `Sources/MDViewer/ContentView.swift`
  renders raw document text through `MarkdownUI`, which has no frontmatter concept. The
  upstream parser (`swift-markdown-ui` 2.4.1 → cmark-gfm) is behaving per CommonMark; the
  defect is our missing pre-processing step, not an upstream bug.
- **Fixable in this repo?** yes

**Evidence anchor.** `ContentView.swift:16-18` feeds unmodified `document.text` into
`parsedSections()`, and `ContentView.swift:128-139` renders each section's raw string through
`Markdown(...)`. Nothing in `Sources/MDViewer/` matches `---` as a frontmatter fence
(`DocumentSection.swift:45-52` recognises ATX headings only).

Reproduced against a CommonMark reference parser (same block-level grammar as cmark-gfm for
this construct). **Common case — no blank line in the block:**

```
---
title: BTS-2965 — MT Table Calculation Design
author: Pierre Oosthuizen
tags: [calypso, mt]
---
```
→ `<hr />` + `<h2>title: … author: … tags: …</h2>`

The opening `---` parses as a **thematic break**; the YAML body followed by the closing `---`
parses as a **setext H2 underline**, so the metadata renders as a rule plus one oversized
heading.

**Variant — a blank line inside the block** splits the reading:
```
---
title: Hello

tags: [a, b]
---
```
→ `<hr />` + `<p>title: Hello</p>` + `<h2>tags: [a, b]</h2>`

i.e. part of the metadata leaks in as ordinary body text. The misrender is therefore not
always "one oversized heading" — but every variant is a misrender, and the fix (a fence-based
split *before* cmark ever sees the text) is insensitive to which variant occurs.

_Caveat on the issue's screenshot: it is cropped and starts at the document's H1, so it does
not itself show the frontmatter. The diagnosis rests on the reproductions above, not the image._

**Corpus evidence** (survey of `~/SecondBrain/My Development Knowledge Base`, 209 `.md` files):
176 documents carry frontmatter. Line shapes observed: `key: value` scalar ×936, block-sequence
item ×668, empty-value key ×155, inline flow list ×70. **Zero** occurrences of nested mappings,
`|`/`>` block scalars, YAML comments, blank lines inside a block, or unshaped lines. This
survey sets the parser scope in §4 and the out-of-scope list in §10.

## 3. Affected files / modules

**New:**
- `Sources/MDViewer/Frontmatter.swift` — fence detection, the §4 validation gate, key/value
  extraction, and the `(frontmatter, body)` split.
- `Sources/MDViewer/FrontmatterTableView.swift` — the SwiftUI key/value table.
- `Tests/MDViewerTests/FrontmatterTests.swift` — parser unit tests.

**Modified:**
- `Sources/MDViewer/ContentView.swift`
  - `sections` (`:16-18`) — parse sections from the **body**, not `document.text`.
  - `cardContent` (`:98-112`) — insert the table above **both** Preview branches (see §4).
  - `sectionedContent` (`:128-139`) — table sits outside its `VStack`, per §4 layout.
  - `filteredText` (`:141-146`) — collateral: the search filter runs over `document.text` and
    currently re-feeds surviving `---` lines into `Markdown(...)`, reproducing the misrender
    while a search is active. Filter over the body instead.
- `project.yml` — add an `MDViewerTests` target **and** the scheme wiring that makes it
  runnable (**no test target and no `schemes:` block exist today**). Concretely:
  ```yaml
  targets:
    MDViewer:
      # …existing config…
      scheme:
        testTargets:
          - MDViewerTests
    MDViewerTests:
      type: bundle.unit-test
      platform: macOS
      sources:
        - path: Tests/MDViewerTests
      dependencies:
        - target: MDViewer
      settings:
        base:
          GENERATE_INFOPLIST_FILE: YES
  ```
  XcodeGen does **not** attach a test target to the app's scheme by name convention; without
  `scheme.testTargets` the generated `MDViewer` scheme has an empty Test action and the §6
  command fails rather than running the tests.
- `MDViewer.xcodeproj/project.pbxproj` — regenerated by `xcodegen generate`, never hand-edited.
- `Documents/Decisions.md` — add **ADR-004: render YAML frontmatter as a metadata table**
  (chosen over a suppression toggle). The repo already carries ADR-001…ADR-003 in this file and
  this change is an explicit recorded decision of the same shape.
- `CHANGELOG.md` — add a `### Fixed` entry under an Unreleased/next-version heading, matching
  the `[0.1.2] ### Fixed` precedent.
- `.gitignore` — collateral: line 20 ignores all of `.claude/`, which would exclude this spec.
  Add a negation so `.claude/specs/` is tracked as a decision record.

**Explicitly unchanged:**
- `DocumentSection.swift` — the split happens before `parsedSections()` is called, so the
  section parser keeps its single responsibility.
- `OutlineSidebarView.swift`, `MarkdownDocument.swift`, `MDViewerApp.swift`, `Format.swift`.
- `ShareLink` (`ContentView.swift:76`) — intentionally keeps sharing raw `document.text` with
  fences included, consistent with Raw mode's byte-verbatim design. Called out so a reader can
  see it was considered, not missed.
- `Sources/Resources/sample.md` — tests use their own fixtures.

## 4. Change approach (design)

`FrontmatterParser.split(document.text)` returns `(Frontmatter?, body: String)`. `ContentView`
renders `FrontmatterTableView` above the body content and passes only `body` to
`parsedSections()`.

### Rendering: dedicated SwiftUI table view · **CHOSEN**

- Values render through `Text`, so they are shown **verbatim** — a value containing `**bold**`,
  `|`, or `#` cannot leak into the Markdown renderer. Deciding argument: metadata is data,
  not content.
- Styled as subdued metadata so it reads as document properties, not a content table.
- Cost: ~40 lines of SwiftUI in one new file.

**Rejected alternative — synthesise a GFM table and prepend it to the body** (MarkdownUI 2.4.1
does support tables). Smaller, and inherits theming for free, but every value would need `|`,
backslash and newline escaping, any un-escaped Markdown in a value would still be interpreted,
and the metadata would be indistinguishable from a real content table.

### Table layout (specified so the implementer need not guess)

- Two columns, **no header row** — a "Key | Value" header adds noise to what is visually a
  properties block.
- Key column: secondary foreground colour, trailing-aligned, fixed max width ~180pt; keys
  longer than that wrap.
- Value column: primary colour, leading-aligned, wraps to multiple lines (no truncation) so
  long values such as URLs stay readable.
- Hairline separator between rows; the whole table has the same horizontal insets as the body.
- Rendered **above** `sectionedContent`'s `VStack`, not inside it, with an explicit 28pt gap
  below the table to match the existing inter-section spacing (`ContentView.swift:131`).
- The table is **line-spacing invariant** by design: it does not take the Line Spacing
  preference (`ContentView.swift:68-74`), because a compact properties block is the intent.
  It *does* track the existing font-size preference.

### Parser scope

Deliberately a minimal line scanner, **not** a YAML engine — no new dependency (§10). Scope is
set by the corpus survey in §2, which covers 100% of the line shapes in 176 real documents.

**Normalization.** Normalize `\r\n` and lone `\r` to `\n` before scanning; trim
`.whitespacesAndNewlines` (not `.whitespaces`, which excludes `\r`) on fence-line comparisons
and on extracted keys and values. Strip a leading BOM.

**Fence detection.** Frontmatter is considered only when line 0 is exactly `---`. The
terminator is the next line that is exactly `---` or `...`. A line of 4+ dashes is not a fence.

**Validation gate (fail-safe — prevents silent content loss).** After locating a closing fence,
the enclosed block qualifies as frontmatter only if, ignoring blank lines, **every** line is
one of:
- a key line — unindented, contains `:`, of the form `key:` or `key: value`;
- an indented block-sequence item — `^\s+-\s`;
- an indented continuation line — `^\s+\S`;

**and** at least one key line is present. If any line fails, the block is **not** frontmatter:
`split` returns `nil` and the body is the entire unmodified document.

Without this gate, a document that opens with a stylistic `---` divider and contains any later
lone `---` would have everything between them — including headings — silently deleted from both
the rendered view and the outline. Verified as a live hazard: prose between two fences currently
renders as an H2, so it is visible today and would vanish under a naive fence-only split. The
gate rejects it (no colons → fails), and it rejected **zero** of the 176 real frontmatter
documents in the corpus survey.

**Entry extraction** (in scope, ordered by corpus frequency):
- `key: value` scalars — split on the **first** colon only, so `url: https://x.co/y` is safe.
- Surrounding single/double quotes stripped from the value.
- Empty-value keys (`aliases:`) → entry with an empty-string value; kept, not dropped (155
  occurrences in the corpus).
- Block sequences (`key:` followed by indented `- item` lines) → joined `item, item`
  (668 occurrences — the second most common shape, firmly in scope).
- Inline flow sequences `tags: [a, b]` → `a, b`.
- Duplicate keys preserved in document order (display fidelity beats YAML last-wins).

Anything else — nested mappings, `|`/`>` block scalars, YAML comments — is out of scope (§10);
zero occurrences in the corpus. A `key: |` line degrades to a scalar entry whose value is the
literal `|`, and its indented continuation lines are ignored. This is a documented, harmless
degradation, not a parse failure.

**Empty block.** `---\n---` → fences stripped from the body, **no table rendered**.

### Interaction decisions (settled here, not open questions)

- The table renders in **Preview** mode only. Raw mode is byte-verbatim by design
  (`ContentView.swift:116-126`) and keeps showing the fences.
- The table renders in **both** Preview branches of `cardContent` — the unfiltered
  `sectionedContent` path and the `Markdown(filteredText)` search path — so it stays visible
  while a search filter is active. Filtering applies to the body only; the metadata is a fixed
  document header, not searchable content.
- Frontmatter contributes no outline entry — it is stripped before `parsedSections()`, so
  `OutlineSidebarView`'s `level > 0` filter needs no change.
- **Frontmatter-only document** (real entries, empty body): the table renders and nothing is
  drawn below it. `DocumentSection.swift:39-41`'s fallback must not produce a blank section
  card — suppress the body view when the body trims to empty.

## 5. Contracts / props / interfaces touched

All new and internal to the app target; no existing public signature changes.

```swift
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
    static func split(_ text: String) -> (frontmatter: Frontmatter?, body: String)
}

struct FrontmatterTableView: View {
    let frontmatter: Frontmatter
    let fontSize: Double     // tracks the existing @AppStorage font-size preference
}
```

`ContentView` gains one private computed property holding the split result so the document is
parsed once per render pass rather than once per consumer.

## 6. Test plan

**Test target does not exist yet** — add `MDViewerTests` plus the `scheme.testTargets` wiring
per §3, then regenerate. Use Swift Testing (`import Testing`), available in Xcode 26.6.

```
xcodegen generate
xcodebuild test -project MDViewer.xcodeproj -scheme MDViewer -destination 'platform=macOS'
```

Unit cases against `FrontmatterParser.split`, each with a one-line `///` doc comment per the
project testing standard:

| # | Input | Expected |
|---|---|---|
| 1 | Well-formed block, 3 scalar keys | 3 entries in order; body starts at the first content line |
| 2 | No frontmatter (`# Heading` first) | `nil`; body == input, unmodified |
| 3 | Opening `---`, no closing fence | `nil`; body == input (nothing swallowed) |
| 4 | `---` present but not on line 0 | `nil`; treated as a thematic break in body |
| 5 | Closing fence `...` | parsed identically to `---` |
| 6 | Quoted values (`'a'`, `"b"`) | quotes stripped |
| 7 | Inline list `tags: [a, b]` | value `a, b` |
| 8 | Block list (`tags:` + `  - a` + `  - b`) | value `a, b` |
| 9 | Value containing `:` (`url: https://x.co/y`) | split on the **first** colon only |
| 10 | Value containing Markdown (`title: **b**`) | value retained verbatim, unrendered |
| 11 | Empty block (`---\n---`) | `nil`/empty; fences stripped from body |
| 12 | `----` (four dashes) on line 0 | not a fence; `nil` |
| 13 | CRLF line endings | parsed identically to LF; no stray `\r` in keys or values |
| 14 | **Validation gate:** prose with no colons between two fences | `nil`; body == input — **no content loss** |
| 15 | **Validation gate:** a heading (`# Title`) inside the fenced block | `nil`; body == input; heading still reaches the outline |
| 16 | Empty-value key (`aliases:`) | entry present with empty-string value, not dropped |
| 17 | Blank line inside an otherwise valid block | still parsed; blank line ignored |
| 18 | Block scalar (`desc: \|` + indented prose) | documented degradation: value `\|`, continuation ignored, no crash |
| 19 | Frontmatter-only document (no body) | entries parsed; body empty/whitespace |
| 20 | Duplicate keys | both retained, in document order |

Plus a `parsedSections()` regression: a document with frontmatter produces sections identical
(count, `id`, `level`, `title`, `content`) to the same document with the block removed by hand.

**Manual GUI verification** (the visual half of the acceptance criteria):
1. `xcodebuild -project MDViewer.xcodeproj -scheme MDViewer -configuration Debug build`, then
   launch the built `.app` **explicitly by path** — LaunchServices otherwise routes `open` to
   the installed Homebrew v0.2 build.
2. Open a fixture with frontmatter → table above the body; no rule + giant heading.
3. Toggle Raw → fences visible verbatim. Back to Preview → table returns.
4. Open `Sources/Resources/sample.md` (no frontmatter) → unchanged; no empty table.
5. Type in the Find field → body filters, table remains, no misrender.
6. **Outline navigation:** open a frontmatter fixture with ≥2 headings, click a non-first
   outline entry → the correct section scrolls into view (proves the frontmatter split did not
   shift section IDs against `ContentView.swift:34-39`'s `proxy.scrollTo`).
7. Open a real vault note from `~/SecondBrain/My Development Knowledge Base` (block-sequence
   `tags:` are the common shape there) → table lists the sequence as a comma-joined value.

## 7. i18n impact

None. The app has no localisation infrastructure — all UI strings are inline literals. The
table uses no static labels (no header row), so it adds none.

## 8. Implementation model (complexity → tier)

- **Estimated complexity:** medium
- **Proposed model/executor:** **Sonnet** — the parser and view are well-specified and
  self-contained, but the change spans a new module, two new files, an edit to the app's
  central view, and Xcode project regeneration; the build/test wiring needs a model that can
  iterate on `xcodebuild` output. No security, auth, or data-integrity surface, so no
  stakes-based escalation to Opus.
- **Known iteration hotspots** (flagged so the executing session is not surprised): the
  XcodeGen `scheme.testTargets` wiring in §3 — the §6 command fails without it — and the §4
  validation gate, which is the one piece of logic where a wrong call silently deletes user
  content and therefore deserves its tests written first.

## 9. Open questions / spec-blocking unknowns

1. **Path-rename collision with the stashed PDF-export work.** ✓ Verified: `development` HEAD
   is `b952d3a`, and commit `66d78a1` ("refactor: split sources into macOS / Shared / Util
   layers") exists **only** on `feature/pdf-export` — `git merge-base --is-ancestor 66d78a1
   development` returns false. That commit moves `ContentView.swift`, `DocumentSection.swift`,
   `MarkdownDocument.swift` and `OutlineSidebarView.swift` out of `Sources/MDViewer/`. So the
   two branches collide on (a) those file paths, (b) `project.yml`, where both add an
   `MDViewerTests` target, and (c) `project.pbxproj`.
   *Owner:* Pierre. *Resolve by:* choosing a merge order. Recommendation — land
   `feature/pdf-export` first and rebase this branch onto the new layout, since a path rename
   is cheaper to follow than to lead. The `.pbxproj` conflict is discardable (regenerate).
2. **Should the frontmatter table appear in exported PDFs?** The PDF export path
   (`PDFExportService` / `MarkdownHTMLRenderer`, on `feature/pdf-export`) renders its own HTML
   and hits the identical setext-heading bug. *Owner:* Pierre. *Resolve by:* a decision at
   integration time; out of scope for this branch (§10).

## 10. Out of scope / non-goals

- A YAML library dependency (Yams or similar) or full YAML 1.2 compliance.
- Nested mappings, `|`/`>` block scalars, and YAML comments — **zero occurrences** across the
  176 frontmatter documents surveyed in §2. Block scalars degrade per §4 rather than crash.
- TOML (`+++`) or JSON frontmatter.
- The issue's alternative "switch off frontmatter rendering" toggle and its View-menu item /
  `UserDefaults` key. Not selected; revisit only if requested.
- Editing, writing, or round-tripping frontmatter — the app is a read-only viewer
  (`MarkdownDocument.swift:25-27`).
- An outline sidebar entry, or a search index, for frontmatter keys.
- Frontmatter in the PDF export pipeline (see §9.2).
- Adding frontmatter to `Sources/Resources/sample.md`.
