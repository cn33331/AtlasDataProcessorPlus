import Foundation

class AppConfig {
    static let shared = AppConfig()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let maxRows = "ChannelMaxRows"
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
}
