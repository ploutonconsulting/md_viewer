# PR #10 Review — fix: persist and clamp font size

**Branch:** `codex/persist-font-size` → `main`  
**Files:** `Sources/MDViewer/ContentView.swift`, `Sources/MDViewer/MDViewerApp.swift`  
**Reviewed:** 2026-05-17

---

## Critical

### `UserDefaults(suiteName:)` returns nil — store parameter is dead code

`FontSizePreferences.userDefaults` is defined as:

```swift
static let userDefaults = UserDefaults(suiteName: "com.ploutonconsulting.mdviewer") ?? .standard
```

`UserDefaults(suiteName:)` creates an App Group shared container, not the sandbox container. An App Group suite requires an explicit entitlement (`com.apple.security.application-groups`) with a `group.`-prefixed identifier. Without it the initializer returns `nil` and the fallback `.standard` silently takes over.

Net effect: the `store:` parameter in every `@AppStorage` declaration does nothing. Font size is written to `.standard` as before. If an App Group entitlement is later added, the two stores diverge and all stored values reset.

**Fix:** Remove `FontSizePreferences.userDefaults` and drop the `store:` parameter everywhere. A single sandboxed app with no extensions should use `UserDefaults.standard` throughout.

```swift
// Remove from FontSizePreferences:
// static let userDefaults = UserDefaults(suiteName: "com.ploutonconsulting.mdviewer") ?? .standard

// All @AppStorage declarations become:
@AppStorage(FontSizePreferences.storageKey)
private var fontSize = FontSizePreferences.defaultSize
```

---

## High

### `.onAppear` clamp writes on every window appearance

```swift
.onAppear {
    fontSize = FontSizePreferences.clamped(fontSize)
}
```

`onAppear` fires every time a `DocumentGroup` window appears (e.g. on focus restore). This unconditionally writes to UserDefaults and triggers a re-render even when the stored value is already valid. All mutation paths (`increased`, `decreased`) already clamp, so out-of-range values cannot accumulate at runtime.

**Fix:** Guard the write, or remove entirely.

```swift
.onAppear {
    let clamped = FontSizePreferences.clamped(fontSize)
    if clamped != fontSize { fontSize = clamped }
}
```

---

### `@AppStorage` in `Commands` struct — `.disabled` state will be stale

`FontSizeCommands` holds its own `@AppStorage` binding. `Commands` structs on macOS do not reliably observe external writes to the same key (e.g. toolbar buttons in `ContentView`). The `.disabled` state on Increase/Decrease menu items will lag and show incorrect enabled/disabled state after toolbar use.

**Fix options:**
1. Drop `.disabled` from menu items and accept that bounds are enforced by the action handlers (clamping prevents out-of-range values regardless).
2. Drive menu state via `@FocusedValue` / `@FocusedBinding` passed through the scene environment — the correct SwiftUI pattern for cross-scene command state.

---

## Medium

### Float equality in `isDefault` is fragile

```swift
static func isDefault(_ value: Double) -> Bool {
    value == defaultSize
}
```

Safe today: `defaultSize = 14.0` is exactly representable and steps are integer `±1`. Will silently misfire if step size changes to a non-integer value.

**Fix:**

```swift
static func isDefault(_ value: Double) -> Bool {
    abs(value - defaultSize) < 0.001
}
```

---

## Notes

- `maximumSize` raised from 28 → 32 without mention in PR body. Not a bug, but worth calling out for changelog purposes.
- `FontSizePreferences` and `FontSizeCommands` both live in `MDViewerApp.swift`. Consider moving to `Sources/MDViewer/FontSizePreferences.swift` as the file grows.

---

## Decision

Block merge until the Critical issue is resolved. The `UserDefaults` suite pattern is dead code now and a latent migration hazard later.
