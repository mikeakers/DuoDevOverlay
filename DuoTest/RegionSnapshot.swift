//
//  RegionSnapshot.swift
//  DuoTest
//
//  Plain values describing everything the visualizer draws, plus the pure
//  geometry and formatting it needs. No views live here.
//

import Foundation
import SwiftUI

enum RegionKind: String {
    case division
    case occlusion
}

/// A reserved region copied out of `ReservedRegion` (which has no public
/// initializer) so it can be built in tests.
struct RegionInfo: Identifiable, Equatable {
    /// The system's `ReservedRegion.ID` in the app; any hashable value in tests.
    /// (`ReservedRegion.ID` describes itself as just "ID()", so it can't be
    /// stringified.)
    var id: AnyHashable
    var kind: RegionKind
    /// Includes `margins`, per Apple's reference.
    var frame: CGRect
    var margins: EdgeInsets
    var isActive: Bool

    /// The bare hardware area: `frame` inset by `margins`. Never negative in
    /// size and never outside `frame`.
    var hardwareRect: CGRect {
        let width = max(0, frame.width - margins.leading - margins.trailing)
        let height = max(0, frame.height - margins.top - margins.bottom)
        let x = frame.minX + min(max(0, margins.leading), frame.width - width)
        let y = frame.minY + min(max(0, margins.top), frame.height - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var label: String {
        isActive ? kind.rawValue : "\(kind.rawValue) · inactive"
    }
}

struct HingeInfo: Equatable {
    var status: DeviceHinge.Status
    var degrees: Double

    var statusName: String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partially open"
        case .fullyOpen: "fully open"
        default: "unknown"
        }
    }
}

/// A safe-area inset drawn as a band along one edge.
struct InsetBand: Identifiable, Equatable {
    var edge: Edge
    var rect: CGRect
    var points: CGFloat

    var id: Edge { edge }

    var isVertical: Bool { edge == .leading || edge == .trailing }

    var label: String {
        let name = switch edge {
        case .top: "top"
        case .bottom: "bottom"
        case .leading: "leading"
        case .trailing: "trailing"
        }
        return "\(name) \(Readout.points(points))pt"
    }
}

struct RegionSnapshot: Equatable {
    var size: CGSize
    var safeArea: EdgeInsets
    var regions: [RegionInfo]

    static let empty = RegionSnapshot(size: .zero, safeArea: EdgeInsets(), regions: [])

    var safeRect: CGRect {
        CGRect(x: safeArea.leading,
               y: safeArea.top,
               width: max(0, size.width - safeArea.leading - safeArea.trailing),
               height: max(0, size.height - safeArea.top - safeArea.bottom))
    }

    /// One band per edge with a non-zero inset, in the order top, bottom,
    /// leading, trailing.
    var bands: [InsetBand] {
        var result: [InsetBand] = []
        if safeArea.top > 0 {
            result.append(InsetBand(edge: .top,
                                    rect: CGRect(x: 0, y: 0, width: size.width, height: safeArea.top),
                                    points: safeArea.top))
        }
        if safeArea.bottom > 0 {
            result.append(InsetBand(edge: .bottom,
                                    rect: CGRect(x: 0, y: size.height - safeArea.bottom,
                                                 width: size.width, height: safeArea.bottom),
                                    points: safeArea.bottom))
        }
        if safeArea.leading > 0 {
            result.append(InsetBand(edge: .leading,
                                    rect: CGRect(x: 0, y: 0, width: safeArea.leading, height: size.height),
                                    points: safeArea.leading))
        }
        if safeArea.trailing > 0 {
            result.append(InsetBand(edge: .trailing,
                                    rect: CGRect(x: size.width - safeArea.trailing, y: 0,
                                                 width: safeArea.trailing, height: size.height),
                                    points: safeArea.trailing))
        }
        return result
    }

    /// Where the readout panel goes: the first safe-area corner (top-leading,
    /// top-trailing, bottom-leading, bottom-trailing) clear of every active
    /// region, or else the corner with the least overlap.
    func panelOrigin(for panelSize: CGSize, padding: CGFloat = 12) -> CGPoint {
        let safe = safeRect
        let left = safe.minX + padding
        let right = max(left, safe.maxX - padding - panelSize.width)
        let top = safe.minY + padding
        let bottom = max(top, safe.maxY - padding - panelSize.height)
        let candidates = [
            CGPoint(x: left, y: top),
            CGPoint(x: right, y: top),
            CGPoint(x: left, y: bottom),
            CGPoint(x: right, y: bottom),
        ]
        let obstacles = regions.filter(\.isActive).map(\.frame)

        func overlap(_ origin: CGPoint) -> CGFloat {
            let panel = CGRect(origin: origin, size: panelSize)
            return obstacles.reduce(0) { total, obstacle in
                let shared = panel.intersection(obstacle)
                return shared.isNull ? total : total + shared.width * shared.height
            }
        }

        // `min(by:)` keeps the first of equal elements, so ties go to the
        // earlier (preferred) corner.
        return candidates.min { overlap($0) < overlap($1) } ?? candidates[0]
    }
}

/// Strokes a rect given in the container's coordinates. A zero-width or
/// zero-height rect becomes a line, so a flat fold stays visible.
struct OutlineShape: Shape {
    var rect: CGRect

    var animatableData: CGRect.AnimatableData {
        get { rect.animatableData }
        set { rect.animatableData = newValue }
    }

    func path(in _: CGRect) -> Path {
        var path = Path()
        if rect.width == 0 || rect.height == 0 {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            path.addRect(rect)
        }
        return path
    }
}

enum Readout {
    static func points(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", Double(rounded))
    }

    static func size(_ size: CGSize) -> String {
        "\(points(size.width))×\(points(size.height))"
    }

    static func rect(_ rect: CGRect) -> String {
        "\(points(rect.minX)),\(points(rect.minY)) \(points(rect.width))×\(points(rect.height))"
    }

    static func insets(_ insets: EdgeInsets) -> String {
        "T\(points(insets.top)) L\(points(insets.leading)) B\(points(insets.bottom)) R\(points(insets.trailing))"
    }

    static func sizeClass(_ sizeClass: UserInterfaceSizeClass?) -> String {
        switch sizeClass {
        case .compact: "compact"
        case .regular: "regular"
        case nil: "–"
        @unknown default: "unknown"
        }
    }

    static func hinge(_ hinge: HingeInfo?, received: Bool) -> String {
        guard received else { return "waiting for update" }
        guard let hinge else { return "no hinge" }
        return "\(hinge.statusName) \(Int(hinge.degrees.rounded()))°"
    }
}
