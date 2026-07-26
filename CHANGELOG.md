# Changelog

All notable changes to MDViewer are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-07-26

### Fixed
- YAML frontmatter no longer misrenders as a horizontal rule and an
  oversized heading. A document that opens with a `---`/`---` (or `...`)
  fenced, YAML-shaped block now renders that block as a key/value metadata
  table above the document body in Preview mode; values are shown verbatim,
  so Markdown syntax inside a value is not interpreted. Raw mode is
  unaffected and still shows the fences byte-for-byte. (#11)

## [0.2] - 2026-06-01

### Added
- **Raw / Preview toggle** — switch the document pane between the rendered
  markdown (Preview) and the verbatim, selectable monospaced source (Raw).
- **Line-spacing presets** — a Compact / Normal / Relaxed control that adjusts
  the spacing between lines within the rendered preview. The selection is
  expressed relative to the font size, so it scales as you resize text, and it
  persists across launches.

### Changed
- Increased the spacing between rendered sections so headings no longer butt
  against the previous section's trailing content.

### Removed
- The theme selector (GitHub / DocC / Basic). Rendering now uses a single
  built-in style. This removed a conflict between theme-defined paragraph
  spacing and the new line-spacing presets.

## [0.1.2] - 2026-05-17

### Fixed
- Font-size preference now persists and is clamped to a valid range.

### Added
- Keyboard shortcuts for increasing, decreasing, and resetting text size.

## [0.1.1] - 2026-05-16

### Added
- Developer ID signed and Apple-notarized distribution build.
- macOS AppIcon asset catalog.

## [0.1.0] - 2026-05-12

### Added
- Initial release: native macOS markdown viewer built with SwiftUI and
  MarkdownUI, with outline navigation, font-size controls, and Homebrew cask
  distribution.

[0.2]: https://github.com/ploutonconsulting/md_viewer/releases/tag/v0.2
[0.1.2]: https://github.com/ploutonconsulting/md_viewer/releases/tag/v0.1.2
[0.1.1]: https://github.com/ploutonconsulting/md_viewer/releases/tag/v0.1.1
[0.1.0]: https://github.com/ploutonconsulting/md_viewer/releases/tag/v0.1.0
