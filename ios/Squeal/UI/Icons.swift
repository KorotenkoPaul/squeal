import SwiftUI

/// The web prototype's icons (template.html ICON and the preview's buttons), drawn from the same SVG data.
enum IconPath {
    static let heart = "M12 20.5s-7.5-4.6-9.3-9.2C1.5 8.2 3.4 4.5 7 4.5c2 0 3.4 1.1 5 3 1.6-1.9 3-3 5-3 3.6 0 5.5 3.7 4.3 6.8-1.8 4.6-9.3 9.2-9.3 9.2z"
    static let homeOuter = "M7 3.5h10a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2z"
    static let homeInner = "M9.5 7h5a1 1 0 0 1 1 1v2a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z"
    static let searchCircle = "M16.5 10.5a6 6 0 1 1-12 0a6 6 0 1 1 12 0z"
    static let searchHandle = "M15 15l5 5"
    static let menu = "M4 7h16M4 12h16M4 17h16"
    static let pad = "M7 8h10a5 5 0 0 1 4.8 6.4l-.9 3a2.5 2.5 0 0 1-4.3.9L14.7 16H9.3l-1.9 2.3a2.5 2.5 0 0 1-4.3-.9l-.9-3A5 5 0 0 1 7 8z"
    static let padCross = "M7 11v3M5.5 12.5h3"
    static let padDots = "M17 11.5a1.5 1.5 0 1 1-3 0a1.5 1.5 0 1 1 3 0zM19 13.5a1.5 1.5 0 1 1-3 0a1.5 1.5 0 1 1 3 0z"   // r .6 + the inherited 1.8 stroke
    static let close = "M4 4l8 8M12 4l-8 8"                         // viewBox 16
    static let again = "M3 8a5 5 0 1 0 1.5-3.6M3 2.5V5h2.5"           // viewBox 16
    static let play = "M4.5 2.8v10.4c0 .6.7 1 1.2.6l8-5.2c.5-.3.5-1 0-1.3l-8-5.1c-.5-.4-1.2 0-1.2.6z"
    static let cross = "M6 6l12 12M18 6 6 18"
}

private let v16 = CGRect(x: 0, y: 0, width: 16, height: 16)

struct StrokeIcon: View {
    let paths: [String]
    var viewBox = CGRect(x: 0, y: 0, width: 24, height: 24)
    var width: CGFloat = 1.8                // in viewBox units
    var size: CGFloat
    var body: some View {
        let scale = size / max(viewBox.width, viewBox.height)
        ZStack {
            ForEach(paths, id: \.self) { d in
                SVGShape(d: d, viewBox: viewBox).stroke(style: StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round))
            }
        }.frame(width: size, height: size)
    }
}

enum Icons {
    static func home(_ s: CGFloat) -> some View { StrokeIcon(paths: [IconPath.homeOuter, IconPath.homeInner], width: 1.8, size: s) }
    static func search(_ s: CGFloat) -> some View { StrokeIcon(paths: [IconPath.searchCircle, IconPath.searchHandle], width: 2.2, size: s) }
    static func menu(_ s: CGFloat) -> some View { StrokeIcon(paths: [IconPath.menu], width: 1.8, size: s) }
    static func heart(_ s: CGFloat) -> some View { SVGShape(d: IconPath.heart).frame(width: s, height: s) }
    static func close(_ s: CGFloat) -> some View { StrokeIcon(paths: [IconPath.close], viewBox: v16, width: 1.8, size: s) }
    static func again(_ s: CGFloat) -> some View { StrokeIcon(paths: [IconPath.again], viewBox: v16, width: 1.8, size: s) }
    /// the gamepad: interactive stories (its viewBox is moved 1.6 down so the drawing sits in the middle, BUGS #34)
    static func pad(_ s: CGFloat) -> some View {
        ZStack {
            StrokeIcon(paths: [IconPath.pad, IconPath.padCross], viewBox: CGRect(x: 0, y: 1.6, width: 24, height: 24), width: 1.8, size: s)
            SVGShape(d: IconPath.padDots, viewBox: CGRect(x: 0, y: 1.6, width: 24, height: 24)).frame(width: s, height: s)
        }
    }
}
