# Reserved-region visualizer — design

Date: 2026-11-02
Status: approved in conversation, pending written-spec review

## Goal

A "learn by looking" tool: run DuoTest in the iPhone Duo simulator (or on a
device), move between poses (closed, partially folded, flat) and orientations,
and watch the space the system reserves — the status bar (via safe-area
insets) and the hinge (via reserved regions) — drawn live over the screen.

Nothing is recorded or exported. Success = every reserved area the system
reports is visible, labeled with its numbers, and updates as the pose changes.

## Background facts this design relies on

- Deployment target is iOS 27.2, so iOS 27.1 APIs are available unguarded.
- The status bar is **not** a reserved region. It appears as a one-sided
  safe-area inset; vertical toolbars/tab bars add to the same inset.
- `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`
  returns regions with `id`, `kind` (`.division` / `.occlusion`), `frame`
  (already includes `margins`), `margins`, `isActive`. Default returns only
  active regions; `.includeInactive` adds the rest.
- The fold is a division region, active only while partially folded. Sources
  disagree on whether the inactive fold has a frame or zero width — the
  visualizer should make the answer visible.
- `onHingeChange` delivers `(old, new) DeviceHingeContext`; `hinge` is
  `DeviceHinge?` (nil = no hinge) with `angle: Angle` and
  `status: DeviceHinge.Status` (a struct; switching on it needs `default`).
- The project uses folder-based target membership: new files under
  `DuoTest/` and `DuoTestTests/` join their targets automatically. Default
  actor isolation is `MainActor`.

## Approach

Pure SwiftUI, single screen. No UIKit.

## Components (all in `DuoTest/`)

| File | Responsibility |
|---|---|
| `DuoTestApp.swift` | Unchanged. |
| `ContentView.swift` | Root `NavigationStack`. Owns `showToolbar` state. When on, attaches a standard `.toolbar` with 3–4 plain items so the system can lay them out vertically. Hosts `RegionCanvas`. |
| `RegionSnapshot.swift` | Plain value types, no SwiftUI views: `RegionSnapshot` (size, `EdgeInsets` safe area, `[RegionInfo]`, `HingeInfo?`) and `RegionInfo` (id, kind, frame, margins, isActive). Pure geometry helpers: hardware rect (frame inset by margins), safe-area band rects, readout-panel placement avoiding active regions. |
| `RegionCanvas.swift` | Full-screen `GeometryReader` with `.ignoresSafeArea()`. Builds a `RegionSnapshot` from the proxy on each layout pass (both kinds, `.includeInactive`, `.fixed` layout direction) and draws the layers. Observes `onHingeChange` into `@State`. |
| `ReadoutPanel.swift` | The numbers panel plus the "Show toolbar" toggle (binding from `ContentView`). |

## Data flow

GeometryProxy (size, safe-area insets, reserved regions) + hinge `@State`
→ `RegionSnapshot` → drawing layers + `ReadoutPanel`.

The geometry reader re-evaluates on every layout change (fold, rotate, toolbar
toggle), so the screen updates with no polling. The hinge is used for the
readout only — never for layout.

**Risk:** this assumes `proxy.safeAreaInsets` still reports the insets under
`.ignoresSafeArea()`. If the simulator shows all zeros, read the insets from an
inner safe-area-respecting `GeometryReader` instead and pass them down.

## Visuals (back to front)

Neutral gray background, then:

1. **Safe-area bands** — translucent blue rect on each edge with a non-zero
   inset, labeled with edge name and points (e.g. "trailing 54pt").
2. **Division regions** — translucent orange fill for `frame`; solid orange
   stroke for the hardware rect.
3. **Occlusion regions** — same treatment in magenta.
4. **Inactive regions** — same hue, much fainter fill, dashed stroke, labeled
   "inactive". A zero-width region renders as a dashed line.
5. **Readout panel** — small rounded, semi-opaque material. Shows hinge
   status + angle in degrees (or "no hinge"), view size, horizontal/vertical
   size class, the four insets, and one line per region: kind, active state,
   frame, margins. Holds the toolbar toggle. Placed in the candidate corner
   (top-leading, top-trailing, bottom-leading, bottom-trailing of the safe
   area) whose panel rect doesn't intersect any active region, preferring
   top-leading; if all collide, the one with least overlap. Animates moves.

Region/band changes animate with a short default animation.

## Testing

- **Unit tests** (`DuoTestTests`, Swift Testing) for `RegionSnapshot` helpers:
  - hardware rect from frame + asymmetric margins;
  - band rects for asymmetric insets, omitting zero-inset edges;
  - panel placement: no regions → top-leading; vertical center fold +
    top-leading camera → a corner clear of both; all corners blocked →
    least overlap.
- **Build and run** in the iPhone Duo simulator via
  `DEVELOPER_DIR=/Applications/Xcode-27.2.0-Release.Candidate.app/Contents/Developer`.
  Verify it launches and draws; capture screenshots of whatever poses can be
  driven from the command line. Pose-by-pose correctness is confirmed by the
  user watching the simulator, and will be reported as such.

## Out of scope

Logging/export, UIKit version, camera / inner-camera activation, sample
layouts or `ArrangementView`, right-to-left mirroring comparison.
