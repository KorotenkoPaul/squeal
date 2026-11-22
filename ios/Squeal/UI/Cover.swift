import SwiftUI
import UIKit

/// Cover photos (web/covers/*.jpg, bundled as the folder `covers`), decoded once and kept.
final class CoverCache {
    static let shared = CoverCache()
    private var images: [String: UIImage] = [:]
    func image(_ file: String?) -> UIImage? {
        guard let file else { return nil }
        if let i = images[file] { return i }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("covers/" + file), let i = UIImage(contentsOfFile: url.path) else { return nil }
        images[file] = i
        return i
    }
}

/// img.cover: object-fit cover, object-position center 35%, filter saturate(.85) brightness(.9)
struct CoverImage: View {
    let file: String?
    var vertical: CGFloat = 0.35
    var body: some View {
        GeometryReader { g in
            if let img = CoverCache.shared.image(file) {
                let s = max(g.size.width / img.size.width, g.size.height / img.size.height)
                let w = img.size.width * s, h = img.size.height * s
                Image(uiImage: img)
                    .resizable()
                    .frame(width: w, height: h)
                    .offset(x: (g.size.width - w) / 2, y: (g.size.height - h) * vertical)
                    .saturation(0.85)
                    .colorMultiply(Color(white: 0.9))
            } else {
                Theme.deep
            }
        }
        .clipped()
    }
}
