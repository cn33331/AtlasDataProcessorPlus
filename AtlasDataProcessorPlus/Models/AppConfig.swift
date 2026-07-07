import Cocoa

class AppConfig {
    static let shared = AppConfig()
    
    private let defaults = UserDefaults.standard
    private var configDict: [String: Any] = [:]
    
    private enum Keys {
        static let maxRows = "ChannelMaxRows"
        static let summaryFontSize = "SummaryFontSize"
        static let summaryFontColor = "SummaryFontColor"
        static let summaryFailColor = "SummaryFailColor"
        static let summaryPassColor = "SummaryPassColor"
        static let summaryWindowX = "SummaryWindowX"
        static let summaryWindowY = "SummaryWindowY"
        static let summaryColumns = "SummaryColumns"
        static let tableConfig = "TableConfig"
        static let blockedFailures = "BlockedFailures"
    }
    
    private var configFilePath: String {
        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first ?? ""
        return (appSupportDir as NSString).appendingPathComponent("AtlasDataProcessorPlus")
    }
    
    private var configFileName: String {
        return (configFilePath as NSString).appendingPathComponent("config.json")
    }
    
    private init() {
        loadConfigFromFile()
    }
    
    private func loadConfigFromFile() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: configFilePath) {
            do {
                try fileManager.createDirectory(atPath: configFilePath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("❌ 创建配置目录失败: \(error)")
                return
            }
        }
        
        if fileManager.fileExists(atPath: configFileName) {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: configFileName))
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    configDict = json
                    print("✅ 从配置文件加载成功")
                }
            } catch {
                print("❌ 读取配置文件失败: \(error)")
            }
        }
    }
    
    func saveConfigToFile() {
        let data: [String: Any] = [
            Keys.maxRows: channelMaxRows,
            Keys.summaryFontSize: summaryFontSize,
            Keys.summaryFontColor: summaryFontColor,
            Keys.summaryFailColor: summaryFailColor,
            Keys.summaryPassColor: summaryPassColor,
            Keys.summaryWindowX: summaryWindowX,
            Keys.summaryWindowY: summaryWindowY,
            Keys.summaryColumns: summaryColumns,
            Keys.tableConfig: tableConfig,
            Keys.blockedFailures: Array(blockedFailures)
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: configFileName), options: .atomic)
            configDict = data
            print("✅ 配置文件保存成功")
        } catch {
            print("❌ 保存配置文件失败: \(error)")
        }
    }
    
    private func getIntValue(key: String, defaultValue: Int) -> Int {
        if let value = configDict[key] as? Int {
            return value
        }
        let value = defaults.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }
    
    private func setIntValue(key: String, value: Int) {
        defaults.set(value, forKey: key)
        configDict[key] = value
    }
    
    private func getStringValue(key: String, defaultValue: String) -> String {
        if let value = configDict[key] as? String {
            return value
        }
        return defaults.string(forKey: key) ?? defaultValue
    }
    
    private func setStringValue(key: String, value: String) {
        defaults.set(value, forKey: key)
        configDict[key] = value
    }
    
    var channelMaxRows: Int {
        get {
            return getIntValue(key: Keys.maxRows, defaultValue: 3000)
        }
        set {
            setIntValue(key: Keys.maxRows, value: newValue)
        }
    }
    
    var summaryFontSize: Int {
        get {
            return getIntValue(key: Keys.summaryFontSize, defaultValue: 12)
        }
        set {
            setIntValue(key: Keys.summaryFontSize, value: newValue)
        }
    }
    
    var summaryFontColor: String {
        get {
            return getStringValue(key: Keys.summaryFontColor, defaultValue: "#000000")
        }
        set {
            setStringValue(key: Keys.summaryFontColor, value: newValue)
        }
    }
    
    var summaryFailColor: String {
        get {
            return getStringValue(key: Keys.summaryFailColor, defaultValue: "#FF0000")
        }
        set {
            setStringValue(key: Keys.summaryFailColor, value: newValue)
        }
    }
    
    var summaryPassColor: String {
        get {
            return getStringValue(key: Keys.summaryPassColor, defaultValue: "#00FF00")
        }
        set {
            setStringValue(key: Keys.summaryPassColor, value: newValue)
        }
    }
    
    var summaryWindowX: Int {
        get {
            return getIntValue(key: Keys.summaryWindowX, defaultValue: 20)
        }
        set {
            setIntValue(key: Keys.summaryWindowX, value: newValue)
        }
    }
    
    var summaryWindowY: Int {
        get {
            return getIntValue(key: Keys.summaryWindowY, defaultValue: 900)
        }
        set {
            setIntValue(key: Keys.summaryWindowY, value: newValue)
        }
    }
    
    var summaryColumns: Int {
        get {
            return getIntValue(key: Keys.summaryColumns, defaultValue: 3)
        }
        set {
            setIntValue(key: Keys.summaryColumns, value: newValue)
        }
    }
    
    private var defaultTableConfig: [String: String] = [
        "sn": "PrimaryIdentity",
        "channel": "Fixture Channel ID",
        "s_build": "S_BUILD"
    ]
    
    var tableConfig: [String: String] {
        get {
            if let config = configDict[Keys.tableConfig] as? [String: String] {
                return config
            }
            if let data = defaults.data(forKey: Keys.tableConfig),
               let config = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                return config
            }
            return defaultTableConfig
        }
        set {
            configDict[Keys.tableConfig] = newValue
            if let data = try? JSONSerialization.data(withJSONObject: newValue) {
                defaults.set(data, forKey: Keys.tableConfig)
            }
        }
    }
    
    var blockedFailures: Set<String> {
        get {
            if let failures = configDict[Keys.blockedFailures] as? [String] {
                return Set(failures)
            }
            if let data = defaults.data(forKey: Keys.blockedFailures),
               let failures = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return Set(failures)
            }
            return Set()
        }
        set {
            configDict[Keys.blockedFailures] = Array(newValue)
            if let data = try? JSONSerialization.data(withJSONObject: Array(newValue)) {
                defaults.set(data, forKey: Keys.blockedFailures)
            }
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
    
    func toHexString() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}