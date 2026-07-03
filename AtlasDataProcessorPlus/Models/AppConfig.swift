import Cocoa

class AppConfig {
    static let shared = AppConfig()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let maxRows = "ChannelMaxRows"
        static let summaryFontSize = "SummaryFontSize"
        static let summaryFontColor = "SummaryFontColor"
        static let summaryFailColor = "SummaryFailColor"
        static let summaryPassColor = "SummaryPassColor"
    }
    
    private init() {}
    
    var channelMaxRows: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxRows)
            return value > 0 ? value : 3000
        }
        set {
            defaults.set(newValue, forKey: Keys.maxRows)
        }
    }
    
    var summaryFontSize: Int {
        get {
            let value = defaults.integer(forKey: Keys.summaryFontSize)
            return value > 0 ? value : 12
        }
        set {
            defaults.set(newValue, forKey: Keys.summaryFontSize)
        }
    }
    
    var summaryFontColor: String {
        get {
            return defaults.string(forKey: Keys.summaryFontColor) ?? "#000000"
        }
        set {
            defaults.set(newValue, forKey: Keys.summaryFontColor)
        }
    }
    
    var summaryFailColor: String {
        get {
            return defaults.string(forKey: Keys.summaryFailColor) ?? "#FF0000"
        }
        set {
            defaults.set(newValue, forKey: Keys.summaryFailColor)
        }
    }
    
    var summaryPassColor: String {
        get {
            return defaults.string(forKey: Keys.summaryPassColor) ?? "#00FF00"
        }
        set {
            defaults.set(newValue, forKey: Keys.summaryPassColor)
        }
    }
}

extension NSColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hex.hasPrefix("#") {
            hex.remove(at: hex.startIndex)
        }
        
        if hex.count != 6 {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
            return
        }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgbValue)
        
        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}