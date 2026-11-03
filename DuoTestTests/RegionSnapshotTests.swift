import Testing
import SwiftUI
@testable import DuoTest

@MainActor
struct RegionInfoTests {
    @Test func hardwareRectInsetsFrameByMargins() {
        let fold = RegionInfo(id: "fold", kind: .division,
                              frame: CGRect(x: 380, y: 0, width: 40, height: 700),
                              margins: EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8),
                              isActive: true)
        #expect(fold.hardwareRect == CGRect(x: 392, y: 0, width: 20, height: 700))
    }

    @Test func hardwareRectNeverGoesNegativeOrLeavesFrame() {
        let frame = CGRect(x: 100, y: 50, width: 20, height: 10)
        let region = RegionInfo(id: "r", kind: .occlusion, frame: frame,
                                margins: EdgeInsets(top: 8, leading: 30, bottom: 8, trailing: 30),
                                isActive: true)
        let hardware = region.hardwareRect
        #expect(hardware.width == 0)
        #expect(hardware.height == 0)
        #expect(hardware.minX >= frame.minX && hardware.maxX <= frame.maxX)
        #expect(hardware.minY >= frame.minY && hardware.maxY <= frame.maxY)
    }

    @Test func hardwareRectOfZeroWidthRegionIsZeroWidth() {
        let flatFold = RegionInfo(id: "fold", kind: .division,
                                  frame: CGRect(x: 400, y: 0, width: 0, height: 700),
                                  margins: EdgeInsets(), isActive: false)
        #expect(flatFold.hardwareRect == CGRect(x: 400, y: 0, width: 0, height: 700))
    }

    @Test func labelNamesKindAndMarksInactive() {
        var region = RegionInfo(id: "c", kind: .occlusion, frame: .zero, margins: EdgeInsets(), isActive: true)
        #expect(region.label == "occlusion")
        region.isActive = false
        #expect(region.label == "occlusion · inactive")
    }
}

@MainActor
struct OutlineShapeTests {
    @Test func outlineOfZeroWidthRectIsALine() {
        let path = OutlineShape(rect: CGRect(x: 400, y: 0, width: 0, height: 700))
            .path(in: CGRect(x: 0, y: 0, width: 800, height: 700))
        #expect(!path.isEmpty)
        #expect(path.boundingRect == CGRect(x: 400, y: 0, width: 0, height: 700))
    }

    @Test func outlineOfNormalRectIsThatRect() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        let path = OutlineShape(rect: rect).path(in: CGRect(x: 0, y: 0, width: 800, height: 700))
        #expect(path.boundingRect == rect)
    }
}

@MainActor
struct InsetBandTests {
    @Test func asymmetricInsetsProduceOnlyNonZeroBands() {
        let snapshot = RegionSnapshot(size: CGSize(width: 800, height: 600),
                                      safeArea: EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 54),
                                      regions: [])
        let bands = snapshot.bands
        #expect(bands.map(\.edge) == [.bottom, .trailing])
        #expect(bands[0].rect == CGRect(x: 0, y: 580, width: 800, height: 20))
        #expect(bands[1].rect == CGRect(x: 746, y: 0, width: 54, height: 600))
        #expect(bands[1].isVertical)
        #expect(!bands[0].isVertical)
        #expect(bands[1].label == "trailing 54pt")
    }

    @Test func allFourEdgesInOrder() {
        let snapshot = RegionSnapshot(size: CGSize(width: 400, height: 800),
                                      safeArea: EdgeInsets(top: 59, leading: 10, bottom: 34, trailing: 12.5),
                                      regions: [])
        #expect(snapshot.bands.map(\.edge) == [.top, .bottom, .leading, .trailing])
        #expect(snapshot.bands[0].rect == CGRect(x: 0, y: 0, width: 400, height: 59))
        #expect(snapshot.bands[2].rect == CGRect(x: 0, y: 0, width: 10, height: 800))
        #expect(snapshot.bands[3].label == "trailing 12.5pt")
    }

    @Test func noInsetsNoBands() {
        let snapshot = RegionSnapshot(size: CGSize(width: 800, height: 600), safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.bands.isEmpty)
    }
}

@MainActor
struct PanelPlacementTests {
    let screen = CGSize(width: 800, height: 600)
    let panel = CGSize(width: 200, height: 100)

    func region(_ frame: CGRect, active: Bool = true) -> RegionInfo {
        RegionInfo(id: UUID().uuidString, kind: .occlusion, frame: frame, margins: EdgeInsets(), isActive: active)
    }

    @Test func noRegionsPrefersTopLeading() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }

    @Test func respectsSafeArea() {
        let snapshot = RegionSnapshot(size: screen,
                                      safeArea: EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 54),
                                      regions: [region(CGRect(x: 0, y: 0, width: 120, height: 80))])
        // Top-leading is blocked by the camera; top-trailing sits inside the trailing inset.
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 534, y: 42))
    }

    @Test func avoidsCameraAndFold() {
        let fold = RegionInfo(id: "fold", kind: .division, frame: CGRect(x: 380, y: 0, width: 40, height: 600),
                              margins: EdgeInsets(), isActive: true)
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [fold, region(CGRect(x: 0, y: 0, width: 120, height: 60))])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 12))
    }

    @Test func inactiveRegionsDoNotBlock() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [region(CGRect(x: 0, y: 0, width: 120, height: 60), active: false)])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }

    @Test func regionWithNegativeOriginStillBlocksCorner() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(),
                                      regions: [region(CGRect(x: -20, y: -20, width: 100, height: 60))])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 12))
    }

    @Test func allCornersBlockedPicksLeastOverlap() {
        let snapshot = RegionSnapshot(size: screen, safeArea: EdgeInsets(), regions: [
            region(CGRect(x: 0, y: 0, width: 300, height: 200)),     // covers top-leading
            region(CGRect(x: 500, y: 0, width: 300, height: 200)),   // covers top-trailing
            region(CGRect(x: 0, y: 400, width: 300, height: 200)),   // covers bottom-leading
            region(CGRect(x: 700, y: 500, width: 100, height: 100)), // clips bottom-trailing
        ])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 588, y: 488))
    }

    @Test func panelLargerThanSafeAreaStillReturnsACorner() {
        let snapshot = RegionSnapshot(size: CGSize(width: 150, height: 80), safeArea: EdgeInsets(), regions: [])
        #expect(snapshot.panelOrigin(for: panel) == CGPoint(x: 12, y: 12))
    }
}

@MainActor
struct ReadoutTests {
    @Test func pointsDropTrailingZeroAndRoundToOneDecimal() {
        #expect(Readout.points(54) == "54")
        #expect(Readout.points(12.5) == "12.5")
        #expect(Readout.points(33.333) == "33.3")
        #expect(Readout.points(-20) == "-20")
    }

    @Test func rectSizeAndInsets() {
        #expect(Readout.rect(CGRect(x: 380, y: 0, width: 40.5, height: 700)) == "380,0 40.5×700")
        #expect(Readout.size(CGSize(width: 800, height: 600)) == "800×600")
        #expect(Readout.insets(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 54)) == "T0 L0 B20 R54")
    }

    @Test func sizeClassNames() {
        #expect(Readout.sizeClass(.compact) == "compact")
        #expect(Readout.sizeClass(.regular) == "regular")
        #expect(Readout.sizeClass(nil) == "–")
    }

    @Test func hingeReadoutDistinguishesWaitingFromNoHinge() {
        #expect(Readout.hinge(nil, received: false) == "waiting for update")
        #expect(Readout.hinge(nil, received: true) == "no hinge")
        let hinge = HingeInfo(status: .partiallyOpen, degrees: 92.4)
        #expect(Readout.hinge(hinge, received: true) == "partially open 92°")
    }

    @Test func hingeStatusNames() {
        #expect(HingeInfo(status: .closed, degrees: 0).statusName == "closed")
        #expect(HingeInfo(status: .fullyOpen, degrees: 180).statusName == "fully open")
    }
}
