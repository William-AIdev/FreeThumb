import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
  case system
  case english = "en"
  case simplifiedChinese = "zh-Hans"
  case japanese = "ja"
  case korean = "ko"
  case spanish = "es"
  case hindi = "hi"
  case french = "fr"
  case bengali = "bn"
  case portuguese = "pt"
  case russian = "ru"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .system: "System Default"
    case .english: "English"
    case .simplifiedChinese: "简体中文"
    case .japanese: "日本語"
    case .korean: "한국어"
    case .spanish: "Español"
    case .hindi: "हिन्दी"
    case .french: "Français"
    case .bengali: "বাংলা"
    case .portuguese: "Português"
    case .russian: "Русский"
    }
  }

  var locale: Locale {
    self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
  }
}

func localized(_ key: String) -> String {
  localizedBundle.localizedString(forKey: key, value: key, table: nil)
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: localized(key), arguments: arguments)
}

private var localizedBundle: Bundle {
  let code = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
  guard code != AppLanguage.system.rawValue,
    let path = Bundle.main.path(forResource: code, ofType: "lproj"),
    let bundle = Bundle(path: path)
  else { return .main }
  return bundle
}
