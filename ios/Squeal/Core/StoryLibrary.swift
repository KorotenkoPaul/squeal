import Foundation

/// All stories in all languages, loaded the way web/build.py builds them:
/// - files content/stories/<lang>/*.json (bundled as the folder `stories`), Nobody's Home first, then by file name;
/// - the version `v`, the cover and the cover note come from the English original (progress belongs to the story,
///   not the language);
/// - a story not translated yet is shown in English (setLang in template.html).
final class StoryLibrary {
    static let langs = ["en", "de", "fr", "es", "ru"]

    /// web/build.py COVERS: story id → web/covers/<name>.jpg
    static let covers: [String: String] = [
        "nobodys-home": "legs-doorway", "first-impressions": "laptop-dark", "the-doctor": "forest-path",
        "skinless": "dark-body", "last-train-out": "night-train", "clown": "clown-hush", "grave": "rising-hand",
        "haunted": "foggy-cabin", "reunion": "streetlight-man", "slice": "half-lit-face",
        "unwanted-guest": "behind-blinds", "the-crossroad": "night-couple", "love-till-death": "teal-face",
        "clinical-love": "clinical-love", "frenemy": "frenemy", "perfect-match": "perfect-match",
        "the-crushing-love": "the-crushing-love", "mystery-girlfriend": "mystery-girlfriend",
        "the-reunion-affair": "the-reunion-affair", "under-wrong-hands": "under-wrong-hands",
        "two-knocks": "two-knocks",
    ]
    /// web/build.py COVER_FIX (prototype only: covers to replace before release; not shown in the app)
    static let coverFix: [String: String] = [
        "clinical-love": "a recognisable real person in a professional photo: likeness and copyright",
        "perfect-match": "same photo as First Impressions",
        "under-wrong-hands": "same photo as Unwanted Guest",
    ]

    /// lang → stories in the app's order (for a language: English order, untranslated ones in English)
    private(set) var byLang: [String: [Story]] = [:]
    let root: URL

    init(root: URL) {
        self.root = root
        let en = Self.load(root.appendingPathComponent("en"), english: nil)
        byLang["en"] = en
        let enById = Dictionary(uniqueKeysWithValues: en.map { ($0.id, $0) })
        for lang in Self.langs.dropFirst() {
            let own = Self.load(root.appendingPathComponent(lang), english: enById)
            let ownById = Dictionary(own.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            byLang[lang] = en.map { ownById[$0.id] ?? $0 }
        }
    }

    /// The bundled content (folder reference `stories` in the app bundle).
    static func bundled(_ bundle: Bundle = .main) -> StoryLibrary {
        let url = bundle.resourceURL!.appendingPathComponent("stories")
        return StoryLibrary(root: url)
    }

    func stories(_ lang: String) -> [Story] { byLang[lang] ?? byLang["en"] ?? [] }

    static func sortKey(_ stem: String) -> (Int, String) { (stem == "nobodys-home" ? 0 : 1, stem) }

    private static func load(_ dir: URL, english: [String: Story]?) -> [Story] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let json = files.filter { $0.pathExtension == "json" }.sorted {
            let a = sortKey($0.deletingPathExtension().lastPathComponent), b = sortKey($1.deletingPathExtension().lastPathComponent)
            return a.0 != b.0 ? a.0 < b.0 : a.1.unicodeScalars.map(\.value).lexicographicallyPrecedes(b.1.unicodeScalars.map(\.value))
        }
        var out: [Story] = []
        for f in json {
            guard let data = try? Data(contentsOf: f),
                  let d = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let parsed = StoryParse.story(d) else { continue }
            var s = StoryParse.ordered(parsed, json: data)
            if let en = english {
                guard let e = en[s.id] else { continue }        // a translation of a story that does not exist in English
                s.v = e.v; s.cover = e.cover; s.coverFix = e.coverFix
            } else {
                s.v = StoryParse.version(d)
                if let c = covers[s.id] { s.cover = c + ".jpg" }
                s.coverFix = coverFix[s.id]
            }
            out.append(s)
        }
        return out
    }
}
