import Foundation

/// 开关两侧文字（左：关，右：开），按系统首选语言取词。
enum LocalizedText {
    static var off: String { lookup().off }
    static var on: String { lookup().on }

    private struct Pair { let off: String; let on: String }

    private static func lookup() -> Pair {
        let raw = Locale.preferredLanguages.first?.lowercased() ?? "en"

        if raw.hasPrefix("zh") {
            if raw.contains("hant") || raw.contains("tw") || raw.contains("hk") || raw.contains("mo") {
                return Pair(off: "關", on: "開")
            }
            return Pair(off: "关", on: "开")
        }

        let table: [(prefix: String, pair: Pair)] = [
            ("ja", Pair(off: "オフ", on: "オン")),
            ("ko", Pair(off: "끔", on: "켬")),
            ("fr", Pair(off: "Arrêt", on: "Marche")),
            ("de", Pair(off: "Aus", on: "Ein")),
            ("es", Pair(off: "Apagado", on: "Encendido")),
            ("it", Pair(off: "Spento", on: "Acceso")),
            ("pt", Pair(off: "Desligado", on: "Ligado")),
            ("ru", Pair(off: "Выкл.", on: "Вкл.")),
            ("uk", Pair(off: "Вимк.", on: "Увімк.")),
            ("nl", Pair(off: "Uit", on: "Aan")),
            ("sv", Pair(off: "Av", on: "På")),
            ("da", Pair(off: "Fra", on: "Til")),
            ("nb", Pair(off: "Av", on: "På")),
            ("no", Pair(off: "Av", on: "På")),
            ("fi", Pair(off: "Pois", on: "Päällä")),
            ("pl", Pair(off: "Wył.", on: "Wł.")),
            ("cs", Pair(off: "Vyp.", on: "Zap.")),
            ("tr", Pair(off: "Kapalı", on: "Açık")),
            ("ar", Pair(off: "إيقاف", on: "تشغيل")),
            ("he", Pair(off: "כבוי", on: "פועל")),
            ("th", Pair(off: "ปิด", on: "เปิด")),
            ("vi", Pair(off: "Tắt", on: "Bật")),
            ("id", Pair(off: "Mati", on: "Nyala")),
            ("el", Pair(off: "Ανενεργό", on: "Ενεργό")),
            ("hi", Pair(off: "बंद", on: "चालू")),
            ("hu", Pair(off: "Ki", on: "Be")),
            ("ro", Pair(off: "Oprit", on: "Pornit")),
        ]

        for entry in table where raw.hasPrefix(entry.prefix) {
            return entry.pair
        }
        return Pair(off: "Off", on: "On")
    }
}
