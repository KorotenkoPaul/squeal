import Foundation

extension L10n {
    static let langNames: [(String, String)] = [("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("es", "Español"), ("ru", "Русский")]

    /// tr(): one word of the interface; a missing one falls back to English; {n} etc. are filled in.
    static func tr(_ lang: String, _ key: String, _ vars: [String: String] = [:]) -> String {
        var s = text[lang]?[key] ?? text["en"]?[key] ?? a11y[lang]?[key] ?? a11y["en"]?[key] ?? key
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        // any {x} left unfilled becomes empty, as in the web
        while let r = s.range(of: #"\{\w\}"#, options: .regularExpression) { s.replaceSubrange(r, with: "") }
        return s
    }

    static func list(_ lang: String, _ key: String) -> [String] { lists[lang]?[key] ?? lists["en"]?[key] ?? [] }

    /// First start: the phone's language if it is one of the five, else English.
    static func firstLanguage(_ preferred: [String] = Locale.preferredLanguages) -> String {
        preferred.map { String($0.prefix(2)).lowercased() }.first { text[$0] != nil } ?? "en"
    }

    /// VoiceOver labels in all five languages (IDEAS.md: the web has some of these in English only).
    static let a11y: [String: [String: String]] = [
        "en": ["tabHome": "Stories", "tabFav": "Favourites", "tabSearch": "Search", "tabMenu": "Menu", "close": "Close",
               "favourite": "Favourite", "resetMulti": "Tap: start this part over. Hold: start every part over", "reset": "Start over",
               "interactive": "Interactive story", "pctRead": "{n}% read", "readAll": "Read", "top5": "Top 5 stories this week", "genre": "Genre",
               "a11yPlayVoice": "Play voice message", "a11yPause": "Pause", "a11yVideo": "Video message", "a11yParts": "Parts", "a11yBackChoice": "Back to choice {n}", "a11yAnswer": "Answer"],
        "de": ["tabHome": "Storys", "tabFav": "Favoriten", "tabSearch": "Suchen", "tabMenu": "Menü", "close": "Schließen",
               "favourite": "Favorit", "resetMulti": "Tippen: diesen Teil neu beginnen. Halten: alle Teile neu beginnen", "reset": "Neu beginnen",
               "interactive": "Interaktive Story", "pctRead": "{n} % gelesen", "readAll": "Gelesen", "top5": "Top 5 Storys der Woche", "genre": "Genre",
               "a11yPlayVoice": "Sprachnachricht abspielen", "a11yPause": "Pause", "a11yVideo": "Videonachricht", "a11yParts": "Teile", "a11yBackChoice": "Zurück zur Entscheidung {n}", "a11yAnswer": "Antwort"],
        "fr": ["tabHome": "Histoires", "tabFav": "Favoris", "tabSearch": "Rechercher", "tabMenu": "Menu", "close": "Fermer",
               "favourite": "Favori", "resetMulti": "Toucher : recommencer cette partie. Maintenir : recommencer toutes les parties", "reset": "Recommencer",
               "interactive": "Histoire interactive", "pctRead": "{n} % lu", "readAll": "Lu", "top5": "Top 5 de la semaine", "genre": "Genre",
               "a11yPlayVoice": "Écouter le message vocal", "a11yPause": "Pause", "a11yVideo": "Message vidéo", "a11yParts": "Parties", "a11yBackChoice": "Retour au choix {n}", "a11yAnswer": "Réponse"],
        "es": ["tabHome": "Historias", "tabFav": "Favoritos", "tabSearch": "Buscar", "tabMenu": "Menú", "close": "Cerrar",
               "favourite": "Favorito", "resetMulti": "Toca: empezar esta parte de nuevo. Mantén: empezar todas las partes de nuevo", "reset": "Empezar de nuevo",
               "interactive": "Historia interactiva", "pctRead": "{n} % leído", "readAll": "Leída", "top5": "Top 5 de la semana", "genre": "Género",
               "a11yPlayVoice": "Reproducir mensaje de voz", "a11yPause": "Pausa", "a11yVideo": "Mensaje de video", "a11yParts": "Partes", "a11yBackChoice": "Volver a la elección {n}", "a11yAnswer": "Respuesta"],
        "ru": ["tabHome": "Истории", "tabFav": "Избранное", "tabSearch": "Поиск", "tabMenu": "Меню", "close": "Закрыть",
               "favourite": "В избранное", "resetMulti": "Нажатие: начать эту часть заново. Удержание: начать все части заново", "reset": "Начать заново",
               "interactive": "Интерактивная история", "pctRead": "Прочитано {n}%", "readAll": "Прочитано", "top5": "Топ-5 историй недели", "genre": "Жанр",
               "a11yPlayVoice": "Прослушать голосовое сообщение", "a11yPause": "Пауза", "a11yVideo": "Видеосообщение", "a11yParts": "Части", "a11yBackChoice": "Назад к выбору {n}", "a11yAnswer": "Ответ"],
    ]
}
