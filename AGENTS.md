# AGENTS.md

DuoDevOverlay is a Swift package that a UIKit or SwiftUI app installs as a debug
overlay. The overlay draws the safe-area insets and the iPhone Duo's reserved regions over the running app, with a draggable
readout panel. The reserved regions are the fold (`division`) and the cameras and status block (`occlusion`). The repo holds the package plus two demo apps. See `README.md`
for what users see; this file is what you need to work on it.

## Layout

```
Package.swift                    package "DuoDevOverlay" (iOS 17 minimum, Swift 5 language mode)
Sources/DuoDevOverlay/
  DuoDevOverlay.swift            public install(in:) / uninstall(from:) / isInstalled(in:)
  OverlayWindow.swift            pass-through UIWindow, OverlayStore, OverlayHostingController
  ReservedRegionsView.swift      public SwiftUI view: reads geometry, draws bands/regions/panel
  ReadoutPanel.swift             the numbers panel (generic over an accessory view)
  RegionSnapshot.swift           pure model, geometry and formatting — no views
Tests/DuoDevOverlayTests/        Swift Testing
DuoDevOverlayDemo.xcodeproj      both demo apps; links the package from path "."
DuoDevOverlayDemo/               SwiftUI demo (+ BarSwitches for toolbar/title/tab bar)
DuoDevOverlayDemoTests/          Swift Testing (BarOptions)
DuoDevOverlayDemoUITests/        XCTest UI (panel drag / double-tap)
DuoDevOverlayUIKitDemo/          UIKit demo that installs the overlay from its SceneDelegate
DuoDevOverlayUIKitDemoUITests/   XCTest UI (taps pass through, drag, hide/reinstall, above modal)
Tools/make-icon.swift            draws the app icon: swift Tools/make-icon.swift <out.png>
docs/superpowers/                design specs and implementation plans (history; don't rewrite)
```

## Toolchain

- Use Xcode 27.2 explicitly, even if `xcode-select` points at another Xcode:
  `export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer`.
  - Don't change `xcode-select`.
  - Without `DEVELOPER_DIR`, `xcrun simctl` may not be found.
- Simulator: **iPhone Duo**, `24D777C6-5C3A-4D1C-B22A-D3326828DC88`.
  - It has two displays: 1 is the outer (cover) screen, 3 is the inner one.
  - `xcrun simctl io screenshot` without `--display` captures the inner screen, even while the device is folded.

## Building and testing

All three suites should pass before you commit:

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
D='platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88'

# Package tests. The package's scheme inside the .xcodeproj has no test action,
# so run them from a folder that holds only the package (symlinks back here).
P=/tmp/duodevoverlay-pkg; mkdir -p $P
for f in Package.swift Sources Tests; do ln -sfn "$PWD/$f" "$P/$f"; done
(cd $P && xcodebuild -scheme DuoDevOverlay -destination "$D" test)

# The package must also build for its iOS 17 minimum (this catches missing @available).
(cd $P && xcodebuild -scheme DuoDevOverlay -destination 'generic/platform=iOS Simulator' build)

# The package must also build with Xcode 27.0, if it's installed (this catches 27.1 types outside `#if compiler(>=6.4.1)`).
(cd $P && DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer \
  xcodebuild -scheme DuoDevOverlay -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/duodevoverlay-dd-27.0 build)

# Demo apps (unit + UI tests)
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayDemo -destination "$D" test
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayUIKitDemo -destination "$D" test
```

- The UI tests take about a minute each. Redirect `xcodebuild` output to a file and grep it for `Test run with`, `Executed`, `TEST SUCCEEDED/FAILED` and `error:`.
- If a test target "cannot find" a type that clearly exists, a module in derived data is stale. Use `clean test`.

## Driving the simulator

- Use the **duoctl** skill (`~/.claude/skills/duoctl/scripts/duoctl`) to fold, rotate, tap, swipe and take screenshots. For example: `state`, `close`, `half`, `open`, `hinge 120`, `rotate portrait`, `tap x y`, `screenshot out.png`.
- **Don't use other tap tools.** AXe, idb and similar tools always deliver touches to the outer screen, so on the inner screen they report success and do nothing.
- **Verify every step.** Read the `state` that each duoctl command prints, and check every tap with a screenshot.
- `duoctl elements` and `tap --label` need the AXe CLI. Coordinate taps don't.
- To see an app's `print` output, launch it with
  `xcrun simctl launch --console-pty --terminate-running-process <udid> <bundle-id> > log.txt &`.

## Physical device

- Use `xcrun devicectl list devices` to find the Duo. It works over Wi-Fi.
- Build with `-destination "id=<udid>" -allowProvisioningUpdates`.
- Install with `xcrun devicectl device install app --device <udid> <path.app>`.
- Launch with `xcrun devicectl device process launch --device <udid> --terminate-existing <bundle-id>`. Launch fails with "Locked" while the phone is locked.
- Take a screenshot with `xcrun devicectl device capture screenshot --device <udid> --destination out.png`.

Bundle IDs:
- `com.runway30.DuoDevOverlayDemo`
- `com.runway30.DuoDevOverlayUIKitDemo`

## Code conventions

- **Main actor by default.** Everything is `MainActor` unless you say otherwise: the package sets `.defaultIsolation(MainActor.self)`, and the apps set `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. `MemberImportVisibility` is on, so import every module whose members you use.
- **iOS 17 vs 27.1.** The package declares iOS 17, but the reserved-region and hinge APIs need iOS 27.1. Mark anything that touches `ReservedRegion`, `DeviceHinge`, `reservedRegions(…)` or `onHingeChange` with `@available(iOS 27.1, *)`. The public entry points stay callable from 17: `install` returns early below 27.1.
- **Xcode 27.0 compatibility.** `@available` is checked at runtime, but the iOS 27.0 SDK (Xcode 27.0, Swift 6.4) doesn't have the iOS 27.1 types at all. So everything that touches them also sits inside `#if compiler(>=6.4.1)`; Swift 6.4.1 (Xcode 27.1) is the first toolchain with the iOS 27.1 SDK. Leave the public entry points (`install`, `uninstall`, `isInstalled`, `didChangeNotification`) outside the `#if`, so apps can link the package unconditionally. On older toolchains, `install` does nothing. `ReservedRegionsView` only exists on 27.1+ toolchains.
- **Availability in tests.** Swift Testing rejects `@available` on a suite type. Put it on individual `@Test` functions instead.
- **Reserved-region API facts.**
  - `ReservedRegion` has no public initializer, so tests build `RegionInfo` directly.
  - `ReservedRegion.ID` describes itself as `"ID()"`, so keep it as `AnyHashable`; don't stringify it.
  - `ReservedRegion.Kind` and `DeviceHinge.Status` are structs, so a `switch` over them needs a `default` case.
- **Safe-area insets.** A `GeometryProxy` under `.ignoresSafeArea()` reports zero insets. The view therefore nests two readers: an outer one that respects the safe area (its frame *is* the safe rect) and an inner full-screen one. The insets are the difference between the two frames.
- **Panel frame.** Read the panel's frame (`onGeometryChange` in `.global`) *before* its `.offset`. Read after it, the frame ignores the offset, and the overlay's touch area would stop following the panel.
- **Overlay window.**
  - It sits at window level `.normal + 1` and returns `nil` from `hitTest` outside the panel.
  - It can never become key (`canBecomeKey` is `false`).
  - It is stored on its scene as an associated object (`OverlayStore`), so it can't outlive the scene. Keep these properties, and keep their tests passing.
- **Bar buttons on the outer screen.** UIKit moves bar buttons into a vertical side bar on the Duo's outer screen. A text-only item may not show there at all, so give bar items an image. In UI tests, query `app.buttons[...]`, not `app.navigationBars.buttons[...]`.

## Project file

`DuoDevOverlayDemo.xcodeproj/project.xcproj` uses Xcode 27's JSON format. Targets get their files through folder membership, so a new file in a target's folder joins that target automatically. To edit the project by hand:

- **Validate after every edit.** Run `$DEVELOPER_DIR/usr/bin/xcprojformatter DuoDevOverlayDemo.xcodeproj`. It rejects bad values, and it silently **drops** unknown keys, so diff its output to catch typos.
- **Package declaration.** The local package is declared once at the top level: `"packages": [ { "kind": "local", "path": "." } ]`.
- **Linking a product.** A target links the package's product with
  `"package-product-members": [ { "package": ".", "product-name": "DuoDevOverlay", "build-phase": { "build-phase": "frameworks" } } ]`.
  `package` must match the package's **path**, not its name.
- **New targets.** Each needs:
  - a 24-hex-digit `"id"`;
  - a `"product"` key;
  - a matching entry in the Products group.
  Without those, test schemes fail with "No test bundle product".
- **Schemes** are generated automatically.
- **Stale package paths.** After changing a package path, delete the derived data you build with, or package resolution keeps reporting the old path.

## Git

- `main` is the default branch. The remote is `https://github.com/mikeakers/DuoDevOverlay` (public).
- End commit messages with a `Co-Authored-By:` line for the agent that wrote them.
- Never commit `.claude/`. It holds locally installed skills and stays untracked. Stage with `git add -A -- . ':!.claude'`, or add paths explicitly.
- `.superpowers/` is git-ignored scratch space for plan execution.
