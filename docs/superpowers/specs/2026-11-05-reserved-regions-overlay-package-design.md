# DuoDevOverlay package — design

Date: 2026-11-05
Status: agreed in conversation, waiting for review of this written spec

## Goal

Turn the DuoTest visualizer (now the DuoDevOverlayDemo app) into a Swift
package that a **UIKit** app can add
as a debug overlay. When it is installed, the overlay draws the safe-area
insets and reserved regions (the fold and the occluded areas) over the
running app, along with the draggable readout panel. The app underneath
keeps working normally.

Success:
- The work app adds the package by URL.
- It calls one line from its `SceneDelegate` inside `#if DEBUG`.
- On an iPhone Duo it then sees the same bands, regions and numbers that
  the demo app shows, over its own screens, through folding and rotation.

## Decisions made in conversation

- **Distribution.** A Swift package in this repo, which is renamed to
  `mikeakers/DuoDevOverlay` (still private) and added by URL.
- **Naming.** Everything is renamed away from "DuoTest". See Renaming below.
- **Host app.** The host app's root is UIKit, so the overlay goes in its own
  pass-through `UIWindow` on the host's `UIWindowScene`. Adding a subview to
  the host's window was rejected because modals would cover it and swapping
  the root view controller could bury or remove it.
- **Limits.** The overlay window only sees window-level geometry: the status
  bar, the home indicator, the fold and the cameras. Insets that the host's
  own navigation bars and tab bars add are not visible to it. An
  `attach(to: UIViewController)` mode that would show them is **out of
  scope** for now.
- **Release builds.** Callers exclude the overlay with `#if DEBUG`. The
  package does not check for debug builds itself.

## Assumption to confirm

The work app's deployment target is unknown. So that callers don't need
`if #available` checks:
- The package declares **iOS 17** as its minimum.
- The public API is available from iOS 17.
- `install` does nothing below iOS 27.1.

If the work app's minimum version is higher, nothing changes. If it is
lower than 17, the declared minimum drops to match.

## Renaming

This is done first, as its own step, before any package work.

| Today | After |
|---|---|
| GitHub repo `mikeakers/DuoTest` | `mikeakers/DuoDevOverlay`, renamed with `gh repo rename`. GitHub redirects the old URL. The local `origin` is updated. |
| `DuoTest.xcodeproj` | `DuoDevOverlayDemo.xcodeproj`. It isn't named `DuoDevOverlay.xcodeproj`, so it's distinct from the package at the repo root. |
| App target, scheme and folder `DuoTest` | `DuoDevOverlayDemo` (the SwiftUI demo app) |
| `DuoTestTests`, `DuoTestUITests` | `DuoDevOverlayDemoTests`, `DuoDevOverlayDemoUITests` |
| Bundle ID `com.runway30.DuoTest` (and the test IDs) | `com.runway30.DuoDevOverlayDemo` (and matching test IDs) |
| App display name "DuoTest" | "Duo Overlay" |
| File header comments `//  DuoTest` | Updated to match |
| Local folder `~/repos/DuoTest` | `~/repos/DuoDevOverlay`. The user renames it after the work is merged, because renaming it during the session would pull the working directory out from under it. |

Consequences:
- The new bundle ID installs as a separate app on the Duo, so the user
  deletes the old DuoTest app by hand.
- The old spec and plan under `docs/` stay as they are, as history.

## Repository layout

```
Package.swift                         // library product "DuoDevOverlay"
Sources/DuoDevOverlay/
  RegionSnapshot.swift                // moved from the app; types made public where needed
  RegionCanvas.swift                  // becomes public ReservedRegionsView
  ReadoutPanel.swift                  // bar switches removed; accessory slot added
  OverlayWindow.swift                 // pass-through UIWindow + install/uninstall
Tests/DuoDevOverlayTests/             // RegionSnapshot tests moved from the app's tests
DuoDevOverlayDemo.xcodeproj           // both demo apps; depends on the local package
DuoDevOverlayDemo/                    // the SwiftUI demo (formerly DuoTest)
DuoDevOverlayDemoTests/               // BarOptions tests
DuoDevOverlayDemoUITests/             // drag/double-tap UI test
UIKitDemo/                            // new UIKit demo app target, named DuoDevOverlayUIKitDemo
```

## Public API

```swift
public enum DuoDevOverlay {
    /// Adds the overlay window to `scene`. Calling it again for a scene that
    /// already has the overlay does nothing. Does nothing below iOS 27.1.
    @MainActor public static func install(in scene: UIWindowScene)
    /// Removes the overlay window from `scene`, if it has one.
    @MainActor public static func uninstall(from scene: UIWindowScene)
    @MainActor public static func isInstalled(in scene: UIWindowScene) -> Bool
}

/// The full-screen visualizer as a SwiftUI view, with an optional accessory
/// shown at the top of the readout panel.
@available(iOS 27.1, *)
public struct ReservedRegionsView<Accessory: View>: View {
    public init(@ViewBuilder accessory: () -> Accessory)
}
```

`ReservedRegionsView` is used in two places:
- The overlay window hosts it, with no accessory.
- The demo app uses it in place of its own `RegionCanvas`, passing its Toolbar,
  Nav title and Tab bar switches as the accessory. The demo app therefore keeps
  working exactly as it does today, and the two don't diverge.

## Overlay window

- **Window setup.** A `UIWindow(windowScene:)` subclass:
  - `windowLevel` is `.normal + 1`.
  - The background is clear.
  - `isHidden = false`, and the window is **never** made key.
- **Touches.** `hitTest(_:with:)` returns `nil` unless the touch lands inside
  the readout panel, so every other touch goes to the host app.
  - The panel reports its frame in window coordinates to the window through
    a small shared object.
- **Root view controller.** A `UIHostingController` subclass with a clear
  background, hosting `ReservedRegionsView { CloseButton }`:
  - It does not decide the status bar's appearance, the supported
    orientations, or whether the home indicator auto-hides. Those stay with
    the host's window. This is checked on the device.
- **Close button.** The panel's accessory is a "Hide overlay" button, which
  calls `uninstall`.
- **Panel fit.** The panel is the same as in the demo app: dragged anywhere,
  double-tapped to return to automatic placement, and placed automatically
  to avoid active regions.

## Drawing changes needed for an overlay

- Drop the opaque `Color(white: 0.9)` background. The overlay is
  transparent, and the demo app supplies its own gray behind it.
- Bands and regions have `.allowsHitTesting(false)`.

## UIKitDemo target

Target `DuoDevOverlayUIKitDemo`: a minimal UIKit app that stands in for the work app:
- A `SceneDelegate` with a `UINavigationController` and a plain table of
  rows, plus a tab bar.
- It calls `DuoDevOverlay.install(in:)` inside `#if DEBUG`.
- A bar button item toggles install and uninstall.
- It lets us show that the host app stays fully usable underneath: scrolling
  the table, tapping rows, presenting a modal.

## Testing

- **Package unit tests.** The existing `RegionSnapshot` tests move to the
  package unchanged and are run with `xcodebuild test` on the iPhone Duo
  simulator, since the APIs are iOS-only.
- **Pass-through hit testing.**
  - Unit test: a point outside the panel's frame returns `nil` from the
    window's hit test, and a point inside returns a view.
- **Existing tests.**
  - The demo app's existing UI test (drag and double-tap) must still pass.
  - The `BarOptions` tests stay in DuoDevOverlayDemoTests.
- **UIKitDemo UI test.** With the overlay installed, tapping a table row
  pushes its detail screen, which proves touches pass through. Dragging the
  panel moves it.
- **On the device, checked by the user:**
  - The overlay follows folding and rotation.
  - Region frames match the demo app's.
  - The status bar's appearance and the keyboard aren't affected.

## Risks

- **Regions from a secondary window.** `reservedRegions` and
  `onHingeChange` might behave differently in a non-key secondary window.
  This is checked first, on the device, before anything else is built on it.
- **Orientation and status bar.** The overlay window's root view controller
  could still influence orientation or status bar style. If it does, the
  fallback is overriding those properties so they defer to the host
  window's top view controller.

## Out of scope

- The `attach(to:)` per-view-controller mode.
- A SwiftUI `.overlay` modifier API.
- Shake-to-toggle.
- Logging and export.
- Right-to-left mirroring.
- The minor issues deferred from the visualizer review.
