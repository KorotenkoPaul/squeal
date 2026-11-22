import SwiftUI
import UIKit
import CoreText

extension Color {
    init(hex: UInt32, _ alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: alpha)
    }
}

/// template.html :root colours
enum Theme {
    static let bg = Color(hex: 0x26243f)       // indigo night
    static let deep = Color(hex: 0x17122c)     // card shade behind covers
    static let tabbar = Color(hex: 0x1f1d36)
    static let field = Color(hex: 0x34315a)    // chips, part buttons
    static let text = Color.white
    static let muted = Color(hex: 0x9b97b3)    // lavender captions
    static let accent = Color(hex: 0x7b57c9)   // favourite heart, active states
    static let danger = Color(hex: 0xb5525b)
    static let red = Color(hex: 0xb5525b)
    static let them = Color(hex: 0x36335a)
    static let me = Color(hex: 0x6a4bb8)
    static let tabOff = Color(hex: 0x6f6b8c)
    static let line = Color(hex: 0x9b7ff0)     // progress line, selected-part outline
    static let water = Color(hex: 0x554a8a)
    static let water2 = Color(hex: 0x463d78)
    static let chrome = Color(red: 23 / 255, green: 18 / 255, blue: 44 / 255, opacity: 0.6)   // round buttons over a photo
    static let deepRGB = (r: 23.0 / 255, g: 18.0 / 255, b: 44.0 / 255)
    static func deep(_ a: Double) -> Color { Color(red: deepRGB.r, green: deepRGB.g, blue: deepRGB.b, opacity: a) }
}

/// The interface font: on iPhone the web prototype is drawn in Avenir Next (first in its font list), so the app uses it too.
enum AppFont {
    static func ui(_ size: CGFloat, _ weight: Int = 400) -> Font { Font(uiFont(size, weight)) }
    static func uiFont(_ size: CGFloat, _ weight: Int = 400) -> UIFont {
        let name: String
        switch weight {
        case ..<500: name = "AvenirNext-Regular"
        case 500..<600: name = "AvenirNext-Medium"
        case 600..<700: name = "AvenirNext-DemiBold"
        case 700..<800: name = "AvenirNext-Bold"
        default: name = "AvenirNext-Heavy"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight >= 700 ? .bold : weight >= 600 ? .semibold : .regular)
    }
}

/// The slider's lettering faces (Google Fonts, OFL / Apache, bundled in Fonts/). A face without the letters
/// a language needs (Cyrillic) borrows them from a face of the same kind (template.html FONT_FALLBACK).
enum Lettering {
    /// CSS family name (+ " Italic" for the italic cuts we use) → bundled file
    static let files: [String: String] = [
        "Anton": "Anton-400", "Big Shoulders Display": "BigShouldersDisplay-800", "Caveat": "Caveat-700", "Cinzel": "Cinzel-600",
        "Cormorant SC": "CormorantSC-500", "DM Serif Display": "DMSerifDisplay-Italic-400", "IM Fell English": "IMFellEnglish-Italic-400",
        "Major Mono Display": "MajorMonoDisplay-400", "Monoton": "Monoton-400", "Pinyon Script": "PinyonScript-400",
        "Playfair Display": "PlayfairDisplay-Italic-500", "Rubik Distressed": "RubikDistressed-400", "Rubik Wet Paint": "RubikWetPaint-400",
        "Special Elite": "SpecialElite-400", "Oswald": "Oswald-600", "Marck Script": "MarckScript-400", "PT Mono": "PTMono-400",
        "Russo One": "RussoOne-400",
    ]
    static let fallback: [String: String] = [
        "Anton": "Oswald", "Big Shoulders Display": "Oswald", "Cinzel": "Cormorant SC", "DM Serif Display": "Playfair Display",
        "IM Fell English": "Playfair Display", "Major Mono Display": "PT Mono", "Special Elite": "PT Mono", "Monoton": "Russo One",
        "Pinyon Script": "Marck Script",
    ]
    private static var postScript: [String: String] = [:]

    /// Register every bundled face once, at launch.
    static func register(_ bundle: Bundle = .main) {
        for (family, file) in files {
            guard let url = bundle.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            if let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor], let d = descs.first,
               let name = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String {
                postScript[family] = name
            }
        }
    }

    static func uiFont(_ family: String, _ size: CGFloat) -> UIFont {
        guard let ps = postScript[family], let f = UIFont(name: ps, size: size) else { return AppFont.uiFont(size, 600) }
        if let fb = fallback[family], let fps = postScript[fb] {
            let d = f.fontDescriptor.addingAttributes([.cascadeList: [UIFontDescriptor(name: fps, size: size)]])
            return UIFont(descriptor: d, size: size)
        }
        return f
    }
    static func font(_ family: String, _ size: CGFloat) -> Font { Font(uiFont(family, size)) }
}
