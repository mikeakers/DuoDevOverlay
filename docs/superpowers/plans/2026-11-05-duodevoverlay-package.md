# DuoDevOverlay Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the project, then turn the visualizer into the DuoDevOverlay Swift package. A UIKit app installs it as a pass-through overlay window with one call.

**Architecture:**
- **Package at the repo root.** `Package.swift` sits at the root, and its sources are moved out of the app.
- **Demo project at the root too.** `DuoDevOverlayDemo.xcodeproj` holds the SwiftUI demo app (formerly DuoTest) and a new UIKit demo app, and both link the local package.
- **The overlay.** It is a `UIWindow` subclass that returns `nil` from `hitTest` outside the readout panel. Its root view controller is a `UIHostingController` showing the public SwiftUI `ReservedRegionsView`, and it hands decisions about the status bar and orientation to the app's own view controllers.

**Tech Stack:** Swift 6.4 toolchain (Swift 5 language mode), SwiftUI, UIKit, Swift Package Manager, Swift Testing, XCTest UI tests, Xcode 27.2's JSON project format (`project.xcproj`).

**Spec:** `docs/superpowers/specs/2026-11-05-reserved-regions-overlay-package-design.md`

## Global Constraints

- Toolchain: `export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer`.
  - The 27.2 RC the earlier plan used is gone.
  - Don't run `xcode-select`.
- Simulator destination: `-destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88'` (iPhone Duo).
- Package minimum is **iOS 17**.
  - Anything touching `ReservedRegion`, `DeviceHinge`, `reservedRegions` or `onHingeChange` is `@available(iOS 27.1, *)`.
  - `DuoDevOverlay.install` does nothing below iOS 27.1.
  - The public API is callable from iOS 17 without `if #available`.
- Public API exactly:
  - `DuoDevOverlay.install(in:)`
  - `DuoDevOverlay.uninstall(from:)`
  - `DuoDevOverlay.isInstalled(in:)`
  - `ReservedRegionsView(accessory:)`
  - `ReservedRegionsView()`
- The package does not check for debug builds. Callers wrap `install` in `#if DEBUG`.
- Names after renaming:

| Thing | Name |
|---|---|
| Repo | `mikeakers/DuoDevOverlay` |
| Project | `DuoDevOverlayDemo.xcodeproj` |
| SwiftUI app target / folder | `DuoDevOverlayDemo` |
| Test targets | `DuoDevOverlayDemoTests`, `DuoDevOverlayDemoUITests` |
| Bundle ID | `com.runway30.DuoDevOverlayDemo` |
| App display name | "Duo Overlay" |
| UIKit app target / folder | `DuoDevOverlayUIKitDemo` |
| Its UI tests | `DuoDevOverlayUIKitDemoUITests` |
| Package / library / module | `DuoDevOverlay` |
| Package tests | `DuoDevOverlayTests` |

- The local folder `~/repos/DuoTest` is **not** renamed by this plan.
- Simulator folding, rotation and inner-screen taps: the `duoctl` skill (`~/.claude/skills/duoctl/scripts/duoctl`). Don't use other tap tools; they miss the inner screen.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Project-format notes (verified 2026-11-05 on a scratch copy)

These were found by experiment, using `xcprojformatter` (which rejects or drops invalid keys) and real builds:

- **Declaring the package.** A local package goes at the top level: `"packages": [ { "kind": "local", "path": "." } ]`. `"."` means the folder containing the `.xcodeproj`.
- **Linking a product.** A target links a package product with a target-level key:
  `"package-product-members": [ { "package": ".", "product-name": "DuoDevOverlay", "build-phase": { "build-phase": "frameworks" } } ]`
  - `package` must equal the package's **path** string. Using the package's name fails with "does not uniquely refer to a package".
- **Target IDs.** Every target needs an `"id"` of 24 hex characters. A new target needs no entry in the Products group.
- **Schemes.** These are generated automatically: one per app target, plus one for the package. UI-test targets whose `test-host-target` is an app are included in that app's scheme.
- **Stale paths.** After changing a package path, delete the derived data used for the build, or stale resolution reports the old path.

## Review Focus

1. **Touches through the overlay.** A tap anywhere outside the panel must reach the host app: table rows, bar buttons, and the keyboard.
   - Covered by `OverlayWindowTests` and `OverlayPassThroughUITests.testTapOutsidePanelReachesApp`, and on both screens with the keyboard by Task 5, Steps 4–5 (duoctl).
2. **Above modals.** The overlay must stay above modals presented by the host app.
   - Covered by `OverlayPassThroughUITests.testOverlayStaysAboveModal`.
3. **Install and uninstall.** Calling `install` twice must not add a second window. `uninstall` followed by `install` must bring the overlay back.
   - Covered by `OverlayPassThroughUITests.testHideThenReinstall`, along with the `guard` in `install`.
4. **The demo app.** It must behave exactly as before the move: the bar switches work, and dragging and double-tapping the panel work.
   - Covered by the existing `PanelDragUITests` and `BarOptionsTests`.
5. **Releases older than iOS 27.1.** The package builds for an iOS 17 deployment target, and `install` is a no-op there.
   - Covered by building the package for its declared minimum in Task 2, Step 7. On an older OS, the `#available` guard is the only behaviour.

---

### Task 1: Rename the project to DuoDevOverlayDemo

**Files:**
- Rename: `DuoTest.xcodeproj` → `DuoDevOverlayDemo.xcodeproj`
- Rename: `DuoTest/` → `DuoDevOverlayDemo/`
- Rename: `DuoTestTests/` → `DuoDevOverlayDemoTests/`
- Rename: `DuoTestUITests/` → `DuoDevOverlayDemoUITests/`
- Rename: `DuoDevOverlayDemo/DuoTestApp.swift` → `DuoDevOverlayDemo/DuoDevOverlayDemoApp.swift`
- Rename: `DuoDevOverlayDemoTests/DuoTestTests.swift` → `DuoDevOverlayDemoTests/DuoDevOverlayDemoTests.swift`
- Rename: `DuoDevOverlayDemoUITests/DuoTestUITests.swift` → `DuoDevOverlayDemoUITests/DuoDevOverlayDemoUITests.swift`
- Modify: `DuoDevOverlayDemo.xcodeproj/project.xcproj` (names, bundle IDs, test host, display name)
- Modify: every `.swift` file in the three folders, plus `Tools/make-icon.swift` (`DuoTest` → `DuoDevOverlayDemo`)
- Create: `.gitignore`
- Untrack: `DuoTest.xcodeproj/xcuserdata/` (user state that was committed by accident)

**Interfaces:**
- Consumes: nothing.
- Produces: scheme `DuoDevOverlayDemo`, module `DuoDevOverlayDemo` (tests use `@testable import DuoDevOverlayDemo`), and the `origin` remote at `https://github.com/mikeakers/DuoDevOverlay.git`.

This task is a rename with no behaviour change. Its "test" is that the existing suite passes under the new names.

- [ ] **Step 1: Rename the GitHub repo and point `origin` at it**

```bash
gh repo rename DuoDevOverlay --repo mikeakers/DuoTest --yes
git remote set-url origin https://github.com/mikeakers/DuoDevOverlay.git
gh repo view mikeakers/DuoDevOverlay --json name,visibility -q '.name + " " + .visibility'
```
Expected: `DuoDevOverlay PRIVATE`

- [ ] **Step 2: Move the folders and files**

```bash
git mv DuoTest.xcodeproj DuoDevOverlayDemo.xcodeproj
git mv DuoTest DuoDevOverlayDemo
git mv DuoTestTests DuoDevOverlayDemoTests
git mv DuoTestUITests DuoDevOverlayDemoUITests
git mv DuoDevOverlayDemo/DuoTestApp.swift DuoDevOverlayDemo/DuoDevOverlayDemoApp.swift
git mv DuoDevOverlayDemoTests/DuoTestTests.swift DuoDevOverlayDemoTests/DuoDevOverlayDemoTests.swift
git mv DuoDevOverlayDemoUITests/DuoTestUITests.swift DuoDevOverlayDemoUITests/DuoDevOverlayDemoUITests.swift
git rm -r -q --cached DuoDevOverlayDemo.xcodeproj/xcuserdata
```

- [ ] **Step 3: Rewrite the names inside the files**

Every occurrence of `DuoTest` becomes `DuoDevOverlayDemo`. That covers:
- target names, product paths and the test host;
- bundle IDs (`com.runway30.DuoTest` → `com.runway30.DuoDevOverlayDemo`, and the same for both test bundles);
- file headers, `@testable import`, and the type names `DuoTestApp`, `DuoTestTests` and `DuoTestUITests`.

```bash
for f in DuoDevOverlayDemo.xcodeproj/project.xcproj DuoDevOverlayDemo/*.swift DuoDevOverlayDemoTests/*.swift DuoDevOverlayDemoUITests/*.swift Tools/make-icon.swift; do
  sed -i '' 's/DuoTest/DuoDevOverlayDemo/g' "$f"
done
```

Then add the display name to the app target's build settings in `DuoDevOverlayDemo.xcodeproj/project.xcproj`, right after the `"GENERATE_INFOPLIST_FILE": "YES",` line of the target named `DuoDevOverlayDemo` (the first target):

```json
        "INFOPLIST_KEY_CFBundleDisplayName": "Duo Overlay",
```

- [ ] **Step 4: Add `.gitignore`**

```gitignore
.DS_Store
xcuserdata/
.build/
.swiftpm/
```

- [ ] **Step 5: Check that the project reads and that no old names are left**

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
$DEVELOPER_DIR/usr/bin/xcprojformatter DuoDevOverlayDemo.xcodeproj > /dev/null && echo FORMAT-OK
xcodebuild -project DuoDevOverlayDemo.xcodeproj -list | sed -n '/Targets/,$p'
git grep -n "DuoTest" -- ':!docs' || echo NO-OLD-NAMES
```
Expected:
- `FORMAT-OK`.
- The targets are `DuoDevOverlayDemo`, `DuoDevOverlayDemoTests` and `DuoDevOverlayDemoUITests`, and the scheme is `DuoDevOverlayDemo`.
- `NO-OLD-NAMES`.

- [ ] **Step 6: Run the full suite under the new names**

```bash
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayDemo \
  -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' \
  clean test > /tmp/rename-test.log 2>&1; echo exit=$?; grep -E "Test run with|Executed|TEST (SUCCEEDED|FAILED)" /tmp/rename-test.log | tail -5
```
Expected: `exit=0` and `** TEST SUCCEEDED **`. The Swift Testing count must match the count before renaming (33 tests), and the XCTest UI tests must pass.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Rename the project to DuoDevOverlayDemo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

This plan does not push the feature branch. Pushing happens when the work is merged.

---

### Task 2: Move the visualizer into the DuoDevOverlay package

**Files:**
- Create: `Package.swift`
- Move: `DuoDevOverlayDemo/RegionSnapshot.swift` → `Sources/DuoDevOverlay/RegionSnapshot.swift`
- Move and rewrite: `DuoDevOverlayDemo/RegionCanvas.swift` → `Sources/DuoDevOverlay/ReservedRegionsView.swift`
- Move and rewrite: `DuoDevOverlayDemo/ReadoutPanel.swift` → `Sources/DuoDevOverlay/ReadoutPanel.swift`
- Move: `DuoDevOverlayDemoTests/RegionSnapshotTests.swift` → `Tests/DuoDevOverlayTests/RegionSnapshotTests.swift`
- Create: `DuoDevOverlayDemo/BarSwitches.swift`
- Modify: `DuoDevOverlayDemo/ContentView.swift`
- Modify: `DuoDevOverlayDemo.xcodeproj/project.xcproj` (`packages` entry, plus a `package-product-members` entry on the app target)

**Interfaces:**
- Consumes: the Task 1 names.
- Produces:
  - `@available(iOS 27.1, *) public struct ReservedRegionsView<Accessory: View>: View`, with:
    - `public init(@ViewBuilder accessory: () -> Accessory)`;
    - `public init()` where `Accessory == EmptyView`;
    - `init(onPanelFrameChange: @escaping (CGRect) -> Void, @ViewBuilder accessory: () -> Accessory)`, which is internal. The callback receives the panel's frame in `.global` coordinates.
  - The readout panel keeps the accessibility identifier `"readoutPanel"`.
  - Package scheme `DuoDevOverlay` (from `xcodebuild -list`).

The file is renamed from `RegionCanvas.swift` to `ReservedRegionsView.swift` so it matches the public type. Treat that as a ruling.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 6.2
import PackageDescription

let isolatedToMainActor: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "DuoDevOverlay",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "DuoDevOverlay", targets: ["DuoDevOverlay"]),
    ],
    targets: [
        .target(name: "DuoDevOverlay", swiftSettings: isolatedToMainActor),
        .testTarget(name: "DuoDevOverlayTests",
                    dependencies: ["DuoDevOverlay"],
                    swiftSettings: isolatedToMainActor),
    ],
    swiftLanguageModes: [.v5]
)
```

Declare the package in the project so that `xcodebuild` sees its scheme. (When run from the repo root, `xcodebuild` reads the project, not the bare package.) In `DuoDevOverlayDemo.xcodeproj/project.xcproj`, add this top-level key directly before `"files": [`:

```json
  "packages": [
    { "kind": "local", "path": "." },
  ],
```

```bash
mkdir -p Sources/DuoDevOverlay Tests/DuoDevOverlayTests
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
xcodebuild -project DuoDevOverlayDemo.xcodeproj -list | sed -n '/Schemes/,$p'
```
Expected: the schemes include `DuoDevOverlay`. If Xcode names the package scheme `DuoDevOverlay-Package` instead, use that name in every package command below and record a ruling. The package can't build yet, because its folders are empty.

- [ ] **Step 2: Move the tests first and watch them fail**

```bash
git mv DuoDevOverlayDemoTests/RegionSnapshotTests.swift Tests/DuoDevOverlayTests/RegionSnapshotTests.swift
sed -i '' 's/@testable import DuoDevOverlayDemo/@testable import DuoDevOverlay/' Tests/DuoDevOverlayTests/RegionSnapshotTests.swift
```

In `Tests/DuoDevOverlayTests/RegionSnapshotTests.swift`, the hinge types will only exist from iOS 27.1, so mark the `ReadoutTests` suite. Replace:

```swift
@MainActor
struct ReadoutTests {
```
with:
```swift
@available(iOS 27.1, *)
@MainActor
struct ReadoutTests {
```

Run:
```bash
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay \
  -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' \
  test > /tmp/pkg-red.log 2>&1; echo exit=$?; grep -m3 "error:" /tmp/pkg-red.log
```
Expected: the run fails with errors like `cannot find 'RegionInfo' in scope`, because the sources haven't moved yet.

All later "package test" and "package build" commands in this plan use `-project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay`.

- [ ] **Step 3: Move `RegionSnapshot.swift` and mark the hinge-only pieces**

```bash
git mv DuoDevOverlayDemo/RegionSnapshot.swift Sources/DuoDevOverlay/RegionSnapshot.swift
```

In `Sources/DuoDevOverlay/RegionSnapshot.swift`:
- Change the header's second line from `//  DuoDevOverlayDemo` to `//  DuoDevOverlay`.
- Replace:
```swift
struct HingeInfo: Equatable {
```
with:
```swift
@available(iOS 27.1, *)
struct HingeInfo: Equatable {
```
- Replace:
```swift
    static func hinge(_ hinge: HingeInfo?, received: Bool) -> String {
```
with:
```swift
    @available(iOS 27.1, *)
    static func hinge(_ hinge: HingeInfo?, received: Bool) -> String {
```

- [ ] **Step 4: Write `Sources/DuoDevOverlay/ReadoutPanel.swift`**

```bash
git mv DuoDevOverlayDemo/ReadoutPanel.swift Sources/DuoDevOverlay/ReadoutPanel.swift
```
Replace the whole file with:

```swift
//
//  ReadoutPanel.swift
//  DuoDevOverlay
//

import SwiftUI

/// The numbers: hinge, view size, size classes, insets and every region.
/// `accessory` is shown first, above a divider.
@available(iOS 27.1, *)
struct ReadoutPanel<Accessory: View>: View {
    let snapshot: RegionSnapshot
    let hinge: HingeInfo?
    let hingeReceived: Bool
    /// The panel never grows past this; its contents scroll instead.
    let maxSize: CGSize
    let accessory: Accessory

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            details
                .padding(10)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // Only scroll when the contents overflow, so a drag normally moves the panel.
        .scrollDisabled(contentHeight <= maxSize.height)
        .font(.caption.monospaced())
        .frame(width: min(280, maxSize.width), height: min(contentHeight, maxSize.height))
        .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            // First, so it stays reachable even when the panel has to scroll.
            if Accessory.self != EmptyView.self {
                accessory
                Divider()
            }

            Text(verbatim: "Hinge  \(Readout.hinge(hinge, received: hingeReceived))")
            Text(verbatim: "View   \(Readout.size(snapshot.size))")
            Text(verbatim: "Class  \(Readout.sizeClass(horizontalSizeClass)) × \(Readout.sizeClass(verticalSizeClass))")
            Text(verbatim: "Safe   \(Readout.insets(snapshot.safeArea))")

            Divider()

            if snapshot.regions.isEmpty {
                Text(verbatim: "No reserved regions")
            }
            ForEach(snapshot.regions) { region in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: region.label).bold()
                    Text(verbatim: "  frame   \(Readout.rect(region.frame))")
                    Text(verbatim: "  margins \(Readout.insets(region.margins))")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 5: Write `Sources/DuoDevOverlay/ReservedRegionsView.swift`**

```bash
git mv DuoDevOverlayDemo/RegionCanvas.swift Sources/DuoDevOverlay/ReservedRegionsView.swift
```
Replace the whole file with:

```swift
//
//  ReservedRegionsView.swift
//  DuoDevOverlay
//
//  Full-screen, transparent view that reads the safe area, reserved regions
//  and hinge, and draws them with a draggable readout panel.
//

import SwiftUI

@available(iOS 27.1, *)
extension RegionInfo {
    init(_ region: ReservedRegion) {
        self.init(id: region.id,
                  kind: region.kind == .division ? .division : .occlusion,
                  frame: region.frame,
                  margins: region.margins,
                  isActive: region.isActive)
    }
}

@available(iOS 27.1, *)
extension RegionSnapshot {
    /// Reads every region of both kinds, active and inactive, in physical
    /// (unmirrored) coordinates of the proxy's view. `safeArea` is passed in
    /// because a proxy under `.ignoresSafeArea()` reports zero insets.
    init(_ proxy: GeometryProxy, safeArea: EdgeInsets) {
        let kinds: [ReservedRegion.Kind] = [.division, .occlusion]
        let regions = kinds.flatMap { kind in
            proxy.reservedRegions(kind: kind, options: .includeInactive, layoutDirectionBehavior: .fixed)
        }
        self.init(size: proxy.size, safeArea: safeArea, regions: regions.map { RegionInfo($0) })
    }
}

/// Draws the safe-area insets and reserved regions of the screen it covers,
/// with a readout panel that can be dragged and double-tapped back to its
/// automatic place. The view is transparent: put it over your content.
/// `accessory` appears at the top of the readout panel.
@available(iOS 27.1, *)
public struct ReservedRegionsView<Accessory: View>: View {
    private let accessory: Accessory
    private let onPanelFrameChange: (CGRect) -> Void

    @State private var hinge: HingeInfo?
    @State private var hingeReceived = false
    @State private var panelSize: CGSize = .zero
    @State private var panelPlacement: PanelPlacement = .automatic
    @GestureState private var panelDrag: CGSize = .zero

    public init(@ViewBuilder accessory: () -> Accessory) {
        self.init(onPanelFrameChange: { _ in }, accessory: accessory)
    }

    /// `onPanelFrameChange` receives the panel's frame in global coordinates
    /// whenever it moves or resizes.
    init(onPanelFrameChange: @escaping (CGRect) -> Void, @ViewBuilder accessory: () -> Accessory) {
        self.accessory = accessory()
        self.onPanelFrameChange = onPanelFrameChange
    }

    public var body: some View {
        GeometryReader { safeProxy in
        GeometryReader { proxy in
            // The outer reader is laid out inside the safe area, so its frame
            // *is* the safe rect; the insets are the gap between it and the
            // full-screen inner reader.
            let insets = RegionSnapshot.insets(full: proxy.frame(in: .global),
                                               safe: safeProxy.frame(in: .global))
            let snapshot = RegionSnapshot(proxy, safeArea: insets)
            // Where the panel rests, and where it is right now while dragged.
            let restingOrigin = snapshot.panelOrigin(for: panelSize, placement: panelPlacement)
            let panelOrigin = snapshot.clampedPanelOrigin(
                CGPoint(x: restingOrigin.x + panelDrag.width, y: restingOrigin.y + panelDrag.height),
                panelSize: panelSize)

            ZStack(alignment: .topLeading) {
                Color.clear

                Group {
                    ForEach(snapshot.bands) { band in
                        BandView(band: band)
                    }
                    ForEach(snapshot.regions) { region in
                        RegionView(region: region)
                    }
                }
                .allowsHitTesting(false)

                ReadoutPanel(snapshot: snapshot, hinge: hinge, hingeReceived: hingeReceived,
                             maxSize: snapshot.panelMaxSize(), accessory: accessory)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("readoutPanel")
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { panelSize = $0 }
                    .gesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .global)
                            .updating($panelDrag) { value, drag, _ in drag = value.translation }
                            .onEnded { value in
                                panelPlacement = .manual(CGPoint(x: restingOrigin.x + value.translation.width,
                                                                 y: restingOrigin.y + value.translation.height))
                            }
                    )
                    .onTapGesture(count: 2) { panelPlacement = .automatic }
                    .offset(x: panelOrigin.x, y: panelOrigin.y)
                    // After `.offset`, so the frame includes where the panel is drawn.
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onPanelFrameChange($0) }
            }
            .animation(.snappy, value: snapshot)
            // Animate when the resting place changes (fold, rotate, reset),
            // but not while following a finger.
            .animation(.snappy, value: restingOrigin)
        }
        .ignoresSafeArea()
        }
        .onHingeChange { _, newContext in
            hingeReceived = true
            hinge = newContext.hinge.map { HingeInfo(status: $0.status, degrees: $0.angle.degrees) }
        }
    }
}

@available(iOS 27.1, *)
extension ReservedRegionsView where Accessory == EmptyView {
    public init() {
        self.init { EmptyView() }
    }
}

private struct BandView: View {
    let band: InsetBand

    var body: some View {
        Rectangle()
            .fill(.blue.opacity(0.3))
            .overlay {
                Text(verbatim: band.label)
                    .font(.caption2.monospaced().bold())
                    .foregroundStyle(.blue)
                    .fixedSize()
                    .rotationEffect(band.isVertical ? .degrees(90) : .zero)
            }
            .frame(width: band.rect.width, height: band.rect.height)
            .offset(x: band.rect.minX, y: band.rect.minY)
    }
}

private struct RegionView: View {
    let region: RegionInfo

    private var color: Color { region.kind == .division ? .orange : .pink }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(region.isActive ? 0.35 : 0.08))
                .frame(width: region.frame.width, height: region.frame.height)
                .offset(x: region.frame.minX, y: region.frame.minY)

            OutlineShape(rect: region.hardwareRect)
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: region.isActive ? [] : [6, 4]))

            Text(verbatim: region.label)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(color)
                .padding(2)
                .background(.white.opacity(0.7), in: .rect(cornerRadius: 3))
                .fixedSize()
                .offset(x: region.frame.minX + 4, y: max(region.frame.minY, 0) + 4)
        }
    }
}
```

Note: `.offset` is a render effect, and `onGeometryChange` placed after it is in the offset's *parent* space, so it might report the un-offset frame. Step 9 checks this with a debug print. If the frame doesn't move when the panel is dragged, move that `onGeometryChange` to just before `.offset`. Inside an offset, coordinate-space conversion includes the offset. Record whichever placement works as a ruling.

- [ ] **Step 6: Run the package tests and watch them pass**

Use the same command as Step 2. Expected: `** TEST SUCCEEDED **`. The number of Swift Testing tests is 33 minus the tests still left in DuoDevOverlayDemoTests (the BarOptions tests and the template example). Record the exact numbers.

- [ ] **Step 7: Build the package for its iOS 17 minimum**

```bash
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay -destination 'generic/platform=iOS Simulator' build > /tmp/pkg-build.log 2>&1; echo exit=$?; grep -m5 -E "error:|is only available in iOS" /tmp/pkg-build.log
```
Expected: `exit=0` with no availability errors. Because the package declares `.iOS(.v17)`, the build uses an iOS 17 deployment target. Any code that uses a 27.1 API without being marked fails here.

- [ ] **Step 8: Link the app to the package and give it its switches back**

In `DuoDevOverlayDemo.xcodeproj/project.xcproj`, in the target named `DuoDevOverlayDemo`, add this right after `"product-type": "application",`:

```json
      "package-product-members": [
        { "package": ".", "product-name": "DuoDevOverlay", "build-phase": { "build-phase": "frameworks" } },
      ],
```

Create `DuoDevOverlayDemo/BarSwitches.swift`:

```swift
//
//  BarSwitches.swift
//  DuoDevOverlayDemo
//
//  The demo's own switches, shown at the top of the readout panel.
//

import SwiftUI

struct BarSwitches: View {
    @Binding var options: BarOptions

    var body: some View {
        Toggle("Toolbar", isOn: $options.toolbar)
        Toggle("Nav title", isOn: $options.title)
        Toggle("Tab bar", isOn: $options.tabBar)
    }
}
```

In `DuoDevOverlayDemo/ContentView.swift`:
- Add `import DuoDevOverlay` below `import SwiftUI`.
- Replace:
```swift
            RegionCanvas(options: $options)
```
with:
```swift
            ReservedRegionsView { BarSwitches(options: $options) }
                .background(Color(white: 0.9).ignoresSafeArea())
```

(`ReservedRegionsView` is transparent, so the demo supplies its own gray. The app's deployment target is 27.2, so no `#available` is needed.)

- [ ] **Step 9: Check that the panel frame tracks drags, then run the demo's full suite**

The demo uses the public `init`, which ignores the frame. So temporarily change that `init`'s closure in `ReservedRegionsView.swift` from `{ _ in }` to `{ print("panel", $0) }`, then run the demo's tests. They include the drag UI test:

```bash
rm -rf /tmp/dd-demo
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayDemo \
  -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' \
  -derivedDataPath /tmp/dd-demo test > /tmp/demo-test.log 2>&1; echo exit=$?
grep -E "TEST (SUCCEEDED|FAILED)" /tmp/demo-test.log
xcrun simctl spawn 24D777C6-5C3A-4D1C-B22A-D3326828DC88 log show --last 5m --predicate 'eventMessage CONTAINS "panel ("' --style compact | tail -5
```
Expected:
- `** TEST SUCCEEDED **`, with the BarOptions tests and `PanelDragUITests` passing.
- The logged panel frames include one whose origin differs by about (+40, +180) from the first, which is the drag.

If the origin never changes, apply the fallback from Step 5's note and rerun. Then **remove the `print`** and run the test command once more. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Move the visualizer into the DuoDevOverlay package

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Overlay window and install/uninstall API

**Files:**
- Create: `Sources/DuoDevOverlay/OverlayWindow.swift`
- Create: `Sources/DuoDevOverlay/DuoDevOverlay.swift`
- Test: `Tests/DuoDevOverlayTests/OverlayWindowTests.swift`

**Interfaces:**
- Consumes: the internal `ReservedRegionsView(onPanelFrameChange:accessory:)` from Task 2.
- Produces:
  - `@MainActor public enum DuoDevOverlay` with `install(in: UIWindowScene)`, `uninstall(from: UIWindowScene)` and `isInstalled(in: UIWindowScene) -> Bool`.
  - The panel's button is labelled `"Hide overlay"`.
  - `final class OverlayWindow: UIWindow` with `var panelFrame: CGRect`, which is internal.

- [ ] **Step 1: Write the failing hit-test tests**

`Tests/DuoDevOverlayTests/OverlayWindowTests.swift`:

```swift
import Testing
import UIKit
@testable import DuoDevOverlay

@MainActor
struct OverlayWindowTests {
    private func makeWindow(panel: CGRect) -> OverlayWindow {
        let window = OverlayWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.isHidden = false
        window.panelFrame = panel
        return window
    }

    @Test func touchOutsidePanelPassesThrough() {
        let window = makeWindow(panel: CGRect(x: 12, y: 60, width: 280, height: 300))
        #expect(window.hitTest(CGPoint(x: 350, y: 600), with: nil) == nil)
    }

    @Test func touchInsidePanelIsHandledByTheOverlay() {
        let window = makeWindow(panel: CGRect(x: 12, y: 60, width: 280, height: 300))
        #expect(window.hitTest(CGPoint(x: 100, y: 100), with: nil) != nil)
    }

    @Test func beforeThePanelIsLaidOutEveryTouchPassesThrough() {
        let window = makeWindow(panel: .null)
        #expect(window.hitTest(CGPoint(x: 100, y: 100), with: nil) == nil)
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

```bash
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' test > /tmp/ow-red.log 2>&1; echo exit=$?; grep -m3 "error:" /tmp/ow-red.log
```
Expected: the run fails with `cannot find 'OverlayWindow' in scope`.

- [ ] **Step 3: Write `Sources/DuoDevOverlay/OverlayWindow.swift`**

```swift
//
//  OverlayWindow.swift
//  DuoDevOverlay
//
//  The window the overlay lives in. It sits just above the app's window and
//  lets every touch outside the readout panel through to the app.
//

import SwiftUI
import UIKit

final class OverlayWindow: UIWindow {
    /// The readout panel's frame in this window's coordinates. Touches
    /// outside it go to the windows below. `.null` until the panel is laid out.
    var panelFrame: CGRect = .null

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard panelFrame.contains(point) else { return nil }
        return super.hitTest(point, with: event)
    }
}

/// Hosts the overlay, but leaves the status bar, orientation and home
/// indicator to the app's own view controllers.
@available(iOS 27.1, *)
final class OverlayHostingController<Content: View>: UIHostingController<Content> {
    /// The topmost view controller of the app's own window in this scene.
    private var appController: UIViewController? {
        guard let scene = view.window?.windowScene else { return nil }
        let appWindows = scene.windows.filter { !($0 is OverlayWindow) }
        var top = (appWindows.first(where: \.isKeyWindow) ?? appWindows.first)?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    /// Follows a `childFor…` chain down from the app's top view controller,
    /// the way UIKit does for its own window.
    private func deciding(_ child: (UIViewController) -> UIViewController?) -> UIViewController? {
        var controller = appController
        while let current = controller, let next = child(current) {
            controller = next
        }
        return controller
    }

    override var prefersStatusBarHidden: Bool {
        deciding(\.childForStatusBarHidden)?.prefersStatusBarHidden ?? false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        deciding(\.childForStatusBarStyle)?.preferredStatusBarStyle ?? .default
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        deciding(\.childForHomeIndicatorAutoHidden)?.prefersHomeIndicatorAutoHidden ?? false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        appController?.supportedInterfaceOrientations ?? .all
    }
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Same command as Step 2. Expected: `** TEST SUCCEEDED **`, with all three `OverlayWindowTests` passing.

- [ ] **Step 5: Write `Sources/DuoDevOverlay/DuoDevOverlay.swift`**

```swift
//
//  DuoDevOverlay.swift
//  DuoDevOverlay
//
//  Public entry point: put the overlay on a scene, or take it off.
//

import SwiftUI
import UIKit

/// A debug overlay that draws the safe-area insets and reserved regions (the
/// iPhone Duo's fold, cameras and status block) over your app, with a
/// draggable readout panel.
///
/// ```swift
/// #if DEBUG
/// DuoDevOverlay.install(in: windowScene)
/// #endif
/// ```
///
/// The overlay has its own window above the app's, so it stays on top of
/// modals and root-view-controller swaps, and every touch outside the panel
/// reaches the app. It sees window-level geometry only: insets that your own
/// navigation and tab bars add inside your view controllers don't appear.
@MainActor
public enum DuoDevOverlay {
    private static var windows: [ObjectIdentifier: UIWindow] = [:]

    /// Adds the overlay to `scene`. Does nothing if `scene` already has it,
    /// or below iOS 27.1, where the reserved-region APIs don't exist.
    public static func install(in scene: UIWindowScene) {
        guard #available(iOS 27.1, *) else { return }
        let key = ObjectIdentifier(scene)
        guard windows[key] == nil else { return }

        let window = OverlayWindow(windowScene: scene)
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear

        let overlay = ReservedRegionsView(onPanelFrameChange: { [weak window] frame in
            window?.panelFrame = frame
        }) {
            Button("Hide overlay") { [weak scene] in
                if let scene { uninstall(from: scene) }
            }
        }
        let controller = OverlayHostingController(rootView: overlay)
        controller.view.backgroundColor = .clear
        window.rootViewController = controller

        // Shown but never made key, so the app keeps the keyboard and focus.
        window.isHidden = false
        windows[key] = window
    }

    /// Removes the overlay from `scene`, if it has one.
    public static func uninstall(from scene: UIWindowScene) {
        guard let window = windows.removeValue(forKey: ObjectIdentifier(scene)) else { return }
        window.isHidden = true
        window.rootViewController = nil
    }

    /// Whether `scene` currently has the overlay.
    public static func isInstalled(in scene: UIWindowScene) -> Bool {
        windows[ObjectIdentifier(scene)] != nil
    }
}
```

- [ ] **Step 6: Build for the iOS 17 minimum and rerun the package tests**

```bash
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay -destination 'generic/platform=iOS Simulator' build > /tmp/pkg-build.log 2>&1; echo build=$?
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' test > /tmp/pkg-test.log 2>&1; echo test=$?; grep -E "TEST (SUCCEEDED|FAILED)" /tmp/pkg-test.log
```
Expected: `build=0`, `test=0` and `** TEST SUCCEEDED **`.

`install` and `uninstall` need a real `UIWindowScene`, which a package test can't create. They are tested end to end through the UIKit demo in Task 4.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Add the pass-through overlay window and install/uninstall API

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: UIKit demo app, its UI tests, and a README

**Files:**
- Create: `DuoDevOverlayUIKitDemo/AppDelegate.swift`
- Create: `DuoDevOverlayUIKitDemo/SceneDelegate.swift`
- Create: `DuoDevOverlayUIKitDemo/RowsViewController.swift`
- Create: `DuoDevOverlayUIKitDemo/Assets.xcassets/` (a copy of the demo app's asset catalog, so it gets the same icon)
- Create: `DuoDevOverlayUIKitDemoUITests/OverlayPassThroughUITests.swift`
- Modify: `DuoDevOverlayDemo.xcodeproj/project.xcproj` (two folders and two targets)
- Create: `README.md`

**Interfaces:**
- Consumes: `DuoDevOverlay.install(in:)`, `uninstall(from:)` and `isInstalled(in:)`; the panel identifier `"readoutPanel"`; and the `"Hide overlay"` button.
- Produces: scheme `DuoDevOverlayUIKitDemo`, which includes the UI tests.

- [ ] **Step 1: Add the two folders and two targets to the project**

In `files`, after the `DuoDevOverlayDemoUITests` folder entry, add:

```json
    { "kind": "folder", "path": "DuoDevOverlayUIKitDemo", "target-membership": [ "DuoDevOverlayUIKitDemo" ] },
    { "kind": "folder", "path": "DuoDevOverlayUIKitDemoUITests", "target-membership": [ "DuoDevOverlayUIKitDemoUITests" ] },
```

In `targets`, after the closing `}` of the `DuoDevOverlayDemoUITests` target, add:

```json
    {
      "name": "DuoDevOverlayUIKitDemo",
      "id": "D0DE0000000000000000000A",
      "product-type": "application",
      "package-product-members": [
        { "package": ".", "product-name": "DuoDevOverlay", "build-phase": { "build-phase": "frameworks" } },
      ],
      "build-phases": [
        "compile-sources",
        "frameworks",
        "resources",
      ],
      "build-settings": {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "Z8M2Q29GF6",
        "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_CFBundleDisplayName": "Duo Overlay UIKit",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "LD_RUNPATH_SEARCH_PATHS": [
          "$(inherited)",
          "@executable_path/Frameworks",
        ],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.runway30.DuoDevOverlayUIKitDemo",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
        "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
        "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
      },
    }, {
      "name": "DuoDevOverlayUIKitDemoUITests",
      "id": "D0DE0000000000000000000B",
      "product-type": "bundle.ui-testing",
      "test-host-target": "DuoDevOverlayUIKitDemo",
      "dependencies": [
        "DuoDevOverlayUIKitDemo",
      ],
      "build-phases": [
        "compile-sources",
        "frameworks",
        "resources",
      ],
      "build-settings": {
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "Z8M2Q29GF6",
        "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.runway30.DuoDevOverlayUIKitDemoUITests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
        "SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "TEST_TARGET_NAME": "DuoDevOverlayUIKitDemo",
      },
    },
```

Copy the asset catalog:
```bash
mkdir -p DuoDevOverlayUIKitDemo DuoDevOverlayUIKitDemoUITests
cp -R DuoDevOverlayDemo/Assets.xcassets DuoDevOverlayUIKitDemo/Assets.xcassets
```

- [ ] **Step 2: Write the failing UI tests**

`DuoDevOverlayUIKitDemoUITests/OverlayPassThroughUITests.swift`:

```swift
//
//  OverlayPassThroughUITests.swift
//  DuoDevOverlayUIKitDemoUITests
//
//  The overlay over a plain UIKit app: touches outside the panel reach the
//  app, the panel still drags, and the overlay can be hidden and reinstalled.
//

import XCTest

final class OverlayPassThroughUITests: XCTestCase {
    private var app: XCUIApplication!
    private var panel: XCUIElement { app.descendants(matching: .any)["readoutPanel"].firstMatch }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(panel.waitForExistence(timeout: 10), "the overlay should be installed at launch")
        settle()
    }

    @MainActor
    func testTapOutsidePanelReachesApp() throws {
        // A row well clear of the panel and of the tab bar.
        let bottomLimit = app.frame.maxY - 120
        let row = try XCTUnwrap(app.cells.allElementsBoundByIndex.first { cell in
            cell.frame.minY > 0 && cell.frame.maxY < bottomLimit && !cell.frame.intersects(panel.frame)
        }, "no row is clear of the panel")
        let title = row.staticTexts.firstMatch.label

        // A real touch at the row's center, which goes through the overlay window.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5),
                      "tapping \(title) under the overlay should push its screen")
    }

    @MainActor
    func testPanelStillDrags() {
        let start = panel.frame
        let grab = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 40, dy: 180)))
        settle()
        XCTAssertEqual(panel.frame.minX - start.minX, 40, accuracy: 12)
        XCTAssertEqual(panel.frame.minY - start.minY, 180, accuracy: 12)
    }

    @MainActor
    func testHideThenReinstall() {
        app.buttons["Hide overlay"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5), "Hide overlay should remove the panel")

        app.navigationBars.buttons["Overlay"].firstMatch.tap()
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "the Overlay button should reinstall it")
    }

    @MainActor
    func testOverlayStaysAboveModal() {
        app.navigationBars.buttons["Modal"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Modal"].waitForExistence(timeout: 5))
        settle()

        // The panel is still on top, so its button takes the tap rather than the modal.
        app.buttons["Hide overlay"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Modal"].exists, "the modal should be untouched")
    }

    /// Lets placement animations finish.
    private func settle() {
        Thread.sleep(forTimeInterval: 1)
    }
}
```

- [ ] **Step 3: Run them and watch them fail**

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
rm -rf /tmp/dd-uikit
xcodebuild -project DuoDevOverlayDemo.xcodeproj -list | sed -n '/Schemes/,$p'
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayUIKitDemo \
  -destination 'platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88' \
  -derivedDataPath /tmp/dd-uikit test > /tmp/uikit-red.log 2>&1; echo exit=$?; grep -m5 -E "error:|TEST (SUCCEEDED|FAILED)" /tmp/uikit-red.log
```
Expected: the scheme list includes `DuoDevOverlayUIKitDemo`, and the run fails to build because the app has no `@main` entry point yet.

- [ ] **Step 4: Write the app**

`DuoDevOverlayUIKitDemo/AppDelegate.swift`:

```swift
//
//  AppDelegate.swift
//  DuoDevOverlayUIKitDemo
//
//  A plain UIKit app standing in for a real one, to show the overlay
//  installed the way a UIKit app would install it.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
```

`DuoDevOverlayUIKitDemo/SceneDelegate.swift`:

```swift
//
//  SceneDelegate.swift
//  DuoDevOverlayUIKitDemo
//

import DuoDevOverlay
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }

        let tabs = UITabBarController()
        tabs.viewControllers = [
            UINavigationController(rootViewController: RowsViewController(title: "Rows", symbol: "list.bullet")),
            UINavigationController(rootViewController: RowsViewController(title: "More", symbol: "ellipsis.circle")),
        ]

        let window = UIWindow(windowScene: scene)
        window.rootViewController = tabs
        window.makeKeyAndVisible()
        self.window = window

        #if DEBUG
        DuoDevOverlay.install(in: scene)
        #endif
    }
}
```

`DuoDevOverlayUIKitDemo/RowsViewController.swift`:

```swift
//
//  RowsViewController.swift
//  DuoDevOverlayUIKitDemo
//
//  A table of rows that push a detail screen, with bar buttons that toggle
//  the overlay and present a modal.
//

import DuoDevOverlay
import UIKit

final class RowsViewController: UITableViewController {
    init(title: String, symbol: String) {
        super.init(style: .insetGrouped)
        self.title = title
        tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), tag: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Overlay", image: UIImage(systemName: "square.dashed"),
            primaryAction: UIAction { [weak self] _ in self?.toggleOverlay() })
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Modal",
            primaryAction: UIAction { [weak self] _ in self?.presentModal() })
        // A text field, to check the keyboard still comes up with the overlay installed.
        navigationItem.searchController = UISearchController()
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        40
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = "Row \(indexPath.row + 1)"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let detail = UIViewController()
        detail.view.backgroundColor = .systemBackground
        detail.title = "Row \(indexPath.row + 1)"
        navigationController?.pushViewController(detail, animated: true)
    }

    private func toggleOverlay() {
        guard let scene = view.window?.windowScene else { return }
        if DuoDevOverlay.isInstalled(in: scene) {
            DuoDevOverlay.uninstall(from: scene)
        } else {
            DuoDevOverlay.install(in: scene)
        }
    }

    private func presentModal() {
        let modal = UIViewController()
        modal.view.backgroundColor = .systemBackground
        modal.title = "Modal"
        modal.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { [weak modal] _ in modal?.dismiss(animated: true) })
        present(UINavigationController(rootViewController: modal), animated: true)
    }
}
```

- [ ] **Step 5: Run the UI tests and watch them pass**

Use the same test command as Step 3. Expected: `** TEST SUCCEEDED **`, with all four `OverlayPassThroughUITests` passing.

If `testTapOutsidePanelReachesApp` fails because XCUITest can't see the cells through the overlay window, debug it with superpowers:systematic-debugging before changing anything:
- Check `app.debugDescription` for the window order.
- Check whether the overlay window's accessibility tree hides the app's window.
- Fix the cause in the package, for example by giving the overlay's root view `accessibilityViewIsModal = false` or limiting the overlay's accessibility elements to the panel. Don't weaken the test.

- [ ] **Step 6: Write `README.md`**

````markdown
# DuoDevOverlay

A debug overlay for iPhone Duo apps. It draws the safe-area insets (blue)
and the reserved regions — the fold (orange) and the cameras and status block
(pink) — over your running app, with a draggable panel of the exact numbers.
It updates live as the device folds and rotates.

## Add it

In Xcode: **File ▸ Add Package Dependencies…**, enter
`https://github.com/mikeakers/DuoDevOverlay`, and add the `DuoDevOverlay`
library to your app target. (The repo is private: your Xcode account, and any
CI that builds the app, need access to it.)

## Turn it on

In your `UIWindowSceneDelegate`:

```swift
import DuoDevOverlay

func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // … set up your window …
    #if DEBUG
    DuoDevOverlay.install(in: windowScene)
    #endif
}
```

`DuoDevOverlay.uninstall(from:)` removes it and `isInstalled(in:)` tells you
whether it's there — handy for a debug-menu switch. The panel's
**Hide overlay** button uninstalls it too. Drag the panel anywhere; double-tap
it to send it back to its automatic corner.

Callable from iOS 17; it does nothing below iOS 27.1, where the reserved-region
APIs don't exist.

## What it can and can't see

The overlay is its own window above your app's, so it stays on top of modals
and every touch outside the panel reaches your app. A window of its own sees
**window-level** geometry: the status bar, home indicator, fold and cameras.
Insets that your own navigation bars and tab bars add live inside your view
controllers, so they don't show here.

## Demo apps

`DuoDevOverlayDemo.xcodeproj` has two:

- **DuoDevOverlayDemo**: SwiftUI, with switches for a toolbar, navigation
  title and tab bar, to see how each one changes the safe area.
- **DuoDevOverlayUIKitDemo**: a plain UIKit app with the overlay installed
  the way your app would install it.

## License

MIT — see [LICENSE](LICENSE).
````

- [ ] **Step 7: Run everything once more**

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
D='platform=iOS Simulator,id=24D777C6-5C3A-4D1C-B22A-D3326828DC88'
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlay -destination "$D" test > /tmp/all-pkg.log 2>&1; echo pkg=$?
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayDemo -destination "$D" test > /tmp/all-demo.log 2>&1; echo demo=$?
xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme DuoDevOverlayUIKitDemo -destination "$D" test > /tmp/all-uikit.log 2>&1; echo uikit=$?
grep -h -E "TEST (SUCCEEDED|FAILED)" /tmp/all-*.log
```
Expected: `pkg=0`, `demo=0`, `uikit=0`, and three `** TEST SUCCEEDED **` lines.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add the UIKit demo app, its pass-through UI tests, and a README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Check folding, rotation and touches on the simulator with duoctl, then on the Duo

This task has no code. It covers the spec's on-device checks and its first risk: whether regions and hinge updates report correctly from a secondary, non-key window. Most of it runs on the iPhone Duo simulator through the `duoctl` skill, which can fold, rotate, tap and take screenshots. The physical Duo is a final pass at the end.

**Interfaces:**
- Consumes: both demo apps from Tasks 2–4; the panel's text (`Hinge …`, `View …`, `Safe …` and each region's `frame` / `margins` lines); the `Hide overlay` button; and the UIKit demo's rows, search field, `Overlay` and `Modal` buttons.
- Produces: screenshots and notes in the plan workspace (`<workspace>/sim/`), and one ledger line per check.

Notes on `duoctl` (read the skill before starting):
- Run it as `DUOCTL=~/.claude/skills/duoctl/scripts/duoctl`.
- It acts on the only booted iPhone Duo, so boot only `24D777C6-5C3A-4D1C-B22A-D3326828DC88`.
- Every command prints `state` (JSON: `hingeAngle`, `activeScreen`, `orientation`, `sizePoints`). Read it rather than assuming.
- Taps use the active screen's interface points. Use `duoctl tap` for every touch: other tools miss the inner screen.
- **Verify every tap with a screenshot.** A tap reporting success proves nothing.
- On the 27.2 runtime, angles between closed and open land within a few degrees, so compare `hingeAngle` within ±5°.
- `duoctl elements` and `tap --label` need the AXe CLI, which isn't installed. Coordinate taps and screenshots don't need it, so this task is written around screenshots. If the user installs AXe (`brew install cameroncooke/axe/axe`), use `elements` to read the panel text exactly instead of reading it from images.
- If a command succeeds but `state` doesn't change, stop: duoctl's private interfaces have probably changed. Record that and tell the user. Don't retry in a loop.

- [ ] **Step 1: Build both apps for the simulator and install them**

```bash
export DEVELOPER_DIR=/Applications/Xcode-27.2.0.app/Contents/Developer
SIM=24D777C6-5C3A-4D1C-B22A-D3326828DC88
DUOCTL=~/.claude/skills/duoctl/scripts/duoctl
OUT="$(git rev-parse --show-toplevel)/.superpowers/sdd/2026-11-05-duodevoverlay-package/sim"; mkdir -p "$OUT"
xcrun simctl boot $SIM 2>/dev/null; xcrun simctl bootstatus $SIM -b > /dev/null
for s in DuoDevOverlayDemo DuoDevOverlayUIKitDemo; do
  xcodebuild -project DuoDevOverlayDemo.xcodeproj -scheme $s -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath /tmp/dd-sim build > /tmp/sim-$s.log 2>&1; echo "$s build=$?"
  xcrun simctl install $SIM /tmp/dd-sim/Build/Products/Debug-iphonesimulator/$s.app
done
$DUOCTL state
```
Expected: `build=0` for both apps, and a `state` JSON with a `hingeAngle` and an `activeScreen`.

- [ ] **Step 2: Region frames match between the two apps in every pose**

The same poses are run for each app. Launch the app, set the pose, wait for animations, and take a screenshot:

```bash
pose() {  # pose <app-bundle-id> <name> <duoctl args...>
  local app=$1 name=$2; shift 2
  $DUOCTL "$@" > "$OUT/$name-state.json"
  sleep 1.5
  $DUOCTL screenshot "$OUT/$name.png" > /dev/null
  cat "$OUT/$name-state.json"
}
for app in com.runway30.DuoDevOverlayDemo com.runway30.DuoDevOverlayUIKitDemo; do
  short=${app##*.}
  xcrun simctl launch --terminate-running-process $SIM $app > /dev/null; sleep 2
  pose $app $short-closed-portrait   close
  $DUOCTL rotate portrait > /dev/null
  pose $app $short-half              half
  pose $app $short-open              open
  pose $app $short-open-portrait     rotate portrait
  $DUOCTL rotate landscape > /dev/null
done
```

Compare each pose's two screenshots, the SwiftUI demo against the UIKit demo:
- **Fold.** The fold band (orange) is in the same place, with the same width and active/inactive state.
- **Occluded areas.** The camera and status-block regions (pink) are the same.
- **Panel numbers.** The `Safe …` line and every region's `frame` and `margins` line match. One difference is expected: the SwiftUI demo's switches are off, so it has no bars, while the UIKit demo has a navigation bar and a tab bar. Bars don't change regions, and the overlay window shouldn't see the UIKit app's bar insets at all. If the UIKit demo's `Safe` values include bar insets, that is a finding.
- **Half-folded.** In the `half` pose the fold must be **active** in both apps.

Expected: the regions and region numbers are identical in every pose. Record one ledger line per pose. Any mismatch settles the spec's first risk against us. Debug it with superpowers:systematic-debugging before going on.

- [ ] **Step 3: The hinge readout follows the fold in the overlay window**

```bash
xcrun simctl launch --terminate-running-process $SIM com.runway30.DuoDevOverlayUIKitDemo > /dev/null; sleep 2
for angle in 180 120 60; do pose x uikit-hinge-$angle hinge $angle; done
```
Expected: each screenshot's `Hinge` line shows the angle `state` reported (within ±5°), with status `fully open` at 180 and `partially open` at 120 and 60. It must not stay on `waiting for update`. That would mean `onHingeChange` doesn't reach a non-key window.

- [ ] **Step 4: Touches reach the app through the overlay, on both screens**

Run this twice: once after `$DUOCTL close` (outer screen) and once after `$DUOCTL open` (inner screen). Each time:

1. Launch the UIKit demo and take a screenshot. Pick a row whose centre is outside the panel, using coordinates read from the screenshot. Screenshot pixels ÷ screen scale = points, and `state.sizePoints` gives the point size to scale against.
2. `$DUOCTL tap <x> <y>` on that row, then take a screenshot. Expected: the row's detail screen ("Row N" in the navigation bar).
3. Tap the back button area, then the **Modal** bar button, then take a screenshot. Expected: the modal shows, **and** the overlay panel is still drawn on top of it.
4. Tap the panel's **Hide overlay** button, then take a screenshot. Expected: the panel and bands are gone, and the modal is still open.
5. Dismiss the modal (Done), tap **Overlay**, then take a screenshot. Expected: the overlay is back.
6. Tap the second tab, then take a screenshot. Expected: the "More" tab is showing.

Expected: every step's screenshot shows the change. Record a ledger line for each screen.

- [ ] **Step 5: Keyboard and status bar**

With the overlay installed, open the UIKit demo and tap its search field, then take a screenshot.
- Expected: the keyboard appears and typing goes to the field (`$DUOCTL tap` on a key, then a screenshot shows the letter). That shows the overlay window never became key.
- Expected: in every screenshot from Steps 2–5, the status bar matches the app's own appearance with the overlay installed and with it hidden. Compare `uikit-closed-portrait.png` with a screenshot taken after **Hide overlay**.

- [ ] **Step 6: Report the simulator results**

Before touching the device, tell the user the result of each check (Steps 2–5), with the screenshot paths. Include a ledger line `Task 5: simulator checks — <n>/<n> passed`. Any failure is debugged before Step 7.

- [ ] **Step 7: Final pass on the physical Duo (the user drives)**

1. Build for the device, install with `xcrun devicectl device install app`, and launch with `xcrun devicectl device process launch --terminate-existing com.runway30.DuoDevOverlayUIKitDemo`. This works over Wi-Fi.
2. The user checks the things a simulator might not show truthfully:
   - The real camera and status-block occlusion frames.
   - Fold, hinge and rotation behaviour while the device is actually folded by hand.
   - Status bar and keyboard behaviour.
   Screenshots are taken with `xcrun devicectl device capture screenshot` on request.
3. Record the user's results in the ledger.

- [ ] **Step 8: Remind the user**

- Delete the old DuoTest app from the Duo, and from the simulator with `xcrun simctl uninstall 24D777C6-5C3A-4D1C-B22A-D3326828DC88 com.runway30.DuoTest`.
- After merging, rename `~/repos/DuoTest` to `~/repos/DuoDevOverlay`.
