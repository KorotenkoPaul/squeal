import Foundation

/// One story, as in content/stories/<lang>/<id>.json (see content/STORY_FORMAT.md), plus what web/build.py
/// adds: the content version `v` (from the English original), the cover file and the cover note.
struct Story: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let genre: String          // horror / thriller / romance
    let fear: Int              // 1...5
    let description: String
    let interactive: Bool
    let featured: Bool
    let parts: [Part]
    var v: String = ""         // content version: same in every language (English text)
    var cover: String? = nil   // file name in the bundle's covers/ folder, e.g. "legs-doorway.jpg"
    var coverFix: String? = nil

    var totalMessages: Int { parts.reduce(0) { $0 + $1.messages.count } }
}

struct Part: Equatable {
    let prologue: String
    let left: String           // the other side (left, named in the chat header)
    let right: String          // the reader (right)
    let wallpaper: [String]
    let wallpaperEndings: [String: [String]]?
    let start: String?
    let nodes: [String: Node]?
    let messages: [Message]    // interactive: the longest path
}

struct Node: Equatable {
    let messages: [Message]
    let choices: [Choice]?
    let ending: String?
}

struct Choice: Equatable {
    let text: String
    let next: String
}

struct Message: Equatable {
    let from: String
    let text: String
    let voice: String?
    let video: String?
    let dur: Int?
}

// MARK: - Reading the JSON (forgiving: a missing optional field is simply absent)

enum StoryParse {
    static func story(_ d: [String: Any]) -> Story? {
        guard let id = d["id"] as? String, let title = d["title"] as? String,
              let rawParts = d["parts"] as? [[String: Any]] else { return nil }
        let parts = rawParts.compactMap(part)
        guard parts.count == rawParts.count, !parts.isEmpty else { return nil }
        return Story(id: id, title: title, author: d["author"] as? String ?? "", genre: d["genre"] as? String ?? "horror",
                     fear: (d["fear"] as? NSNumber)?.intValue ?? 3, description: d["description"] as? String ?? "",
                     interactive: truthy(d["interactive"]), featured: truthy(d["featured"]), parts: parts)
    }

    static func part(_ p: [String: Any]) -> Part? {
        guard let msgs = p["messages"] as? [[String: Any]] else { return nil }
        var nodes: [String: Node]? = nil
        if let raw = p["nodes"] as? [String: [String: Any]], !raw.isEmpty {
            nodes = raw.compactMapValues(node)
        }
        return Part(prologue: p["prologue"] as? String ?? "", left: p["left"] as? String ?? "", right: p["right"] as? String ?? "",
                    wallpaper: p["wallpaper"] as? [String] ?? [], wallpaperEndings: p["wallpaperEndings"] as? [String: [String]],
                    start: nodes == nil ? nil : p["start"] as? String, nodes: nodes, messages: msgs.compactMap(message))
    }

    static func node(_ n: [String: Any]) -> Node? {
        let msgs = (n["messages"] as? [[String: Any]] ?? []).compactMap(message)
        let choices = (n["choices"] as? [[String: Any]])?.compactMap { c -> Choice? in
            guard let t = c["text"] as? String else { return nil }
            return Choice(text: t, next: c["next"] as? String ?? "")
        }
        return Node(messages: msgs, choices: choices, ending: n["ending"] as? String)
    }

    static func message(_ m: [String: Any]) -> Message? {
        guard let from = m["from"] as? String, let text = m["text"] as? String else { return nil }
        return Message(from: from, text: text, voice: m["voice"] as? String, video: m["video"] as? String,
                       dur: (m["dur"] as? NSNumber)?.intValue)
    }

    private static func truthy(_ x: Any?) -> Bool { (x as? NSNumber)?.boolValue ?? false }

    /// build.py: sha1 of json.dumps([[part.messages, part.nodes or None] ...], ensure_ascii=False, sort_keys=True)[:10]
    static func version(_ d: [String: Any]) -> String {
        let parts = d["parts"] as? [[String: Any]] ?? []
        let body: [Any] = parts.map { p -> [Any] in
            let nodes: Any = { if let n = p["nodes"] as? [String: Any], !n.isEmpty { return n } else { return NSNull() } }()
            return [p["messages"] ?? NSNull(), nodes]
        }
        return PyJSON.sha1Prefix(PyJSON.dumps(body))
    }
}
