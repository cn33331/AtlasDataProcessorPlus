// File: AtlasDataProcessor.swift (修复版)
import Foundation

// ==================== 数据结构定义 ====================
struct CSVRow {
    var attributeName: String = ""
    var attributeValue: String = ""
    var testName: String = ""
    var subTestName: String = ""
    var subSubTestName: String = ""
    var relaxedUpperLimit: String = ""
    var upperLimit: String = ""
    var measurementValue: String = ""
    var lowerLimit: String = ""
    var relaxedLowerLimit: String = ""
    var measurementUnits: String = ""
    var priority: String = ""
    var status: String = ""
    var failureMessage: String = ""
    var startTime: String = ""
    var stopTime: String = ""
    var timeInterval: String = ""
}

struct FileProcessResult {
    var attrNames: [String] = []
    var measureNames: [String] = []
    var measureMeta: [String: [String: String]] = [:]
    var attrDict: [String: String] = [:]
    var measureDict: [String: String] = [:]
    var infoRow: [String] = Array(repeating: "", count: 12)
    var filePathRow: [String] = [""]
}

struct GHConfig {
    var site: String = ""
    var product: String = ""
    var stationId: String = ""
    
    static func loadFromJson(path: String) -> GHConfig {
        var config = GHConfig()
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ghinfo = json["ghinfo"] as? [String: Any] else {
            print("无法打开GH配置文件: \(path)")
            return config
        }
        
        config.site = ghinfo["SITE"] as? String ?? ""
        config.product = ghinfo["PRODUCT"] as? String ?? ""
        config.stationId = ghinfo["STATION_ID"] as? String ?? ""
        
        return config
    }
}

// MARK: - 工具函数
enum AtlasUtils {
    static func split(_ str: String, delimiter: Character) -> [String] {
        // 使用 split(omittingEmptySubsequences: false) 来保留空值
        return str.split(separator: delimiter, 
                        maxSplits: Int.max, 
                        omittingEmptySubsequences: false)
                .map(String.init)
    }
        
    static func trim(_ str: String) -> String {
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func readCSVFile(filePath: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            print("无法打开文件: \(filePath)")
            return rows
        }
        
        let lines = content.components(separatedBy: .newlines)
        var isFirstLine = true
        
        for line in lines {
            let trimmedLine = trim(line)
            guard !trimmedLine.isEmpty else { continue }
            
            if isFirstLine {
                isFirstLine = false
                continue // 跳过标题行
            }
            var tokens = split(trimmedLine, delimiter: ",")
            if tokens.count < 17 {
                tokens.append(contentsOf: Array(repeating: "", count: 17 - tokens.count))
            }
            
            var row = CSVRow()
            row.attributeName = trim(tokens[0])
            row.attributeValue = trim(tokens[1])
            row.testName = trim(tokens[2])
            row.subTestName = trim(tokens[3])
            row.subSubTestName = trim(tokens[4])
            row.relaxedUpperLimit = trim(tokens[5])
            row.upperLimit = trim(tokens[6])
            row.measurementValue = trim(tokens[7])
            row.lowerLimit = trim(tokens[8])
            row.relaxedLowerLimit = trim(tokens[9])
            row.measurementUnits = trim(tokens[10])
            row.priority = trim(tokens[11])
            row.status = trim(tokens[12])
            row.failureMessage = trim(tokens[13])
            row.startTime = trim(tokens[14])
            row.stopTime = trim(tokens[15])
            row.timeInterval = trim(tokens[16])
            rows.append(row)
        }
        
        return rows
    }
}

// MARK: - AtlasDataProcessor 类
class AtlasDataProcessor {
    
    // MARK: - 私有属性
    private var recordsFiles: [String] = []
    private var ghConfig = GHConfig()
    private var allAttributeNames: Set<String> = []
    private var allMeasureNames: Set<String> = []
    private var measureMetaDict: [String: [String: String]] = [:]
    private var fileResults: [FileProcessResult] = []
    
    private var sortedAttrNames: [String] = []
    private var sortedMeasureNames: [String] = []
    private var allParamNames: [String] = []
    
    private var unitRow: [String] = []
    private var upperLimitRow: [String] = []
    private var lowerLimitRow: [String] = []
    
    private(set) var finalData: [[String]] = []
    private(set) var finalDataPlus: [[String]] = []
    
    private let fixedColumns = 12
    private let timestamp: String
    
    // MARK: - 公开接口
    var processedCount: Int { return recordsFiles.count }
    var parameterCount: Int { return allParamNames.count }
    var failureCount: Int { return extractFailInfo().count }
    
    // MARK: - 初始化
    init() {
        // 生成时间戳
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        formatter.timeZone = TimeZone.current
        timestamp = formatter.string(from: Date())
        
        // 加载GH配置
        let ghPath = "/vault/data_collection/test_station_config/gh_station_info.json"
        ghConfig = GHConfig.loadFromJson(path: ghPath)
    }
    
    // MARK: - 主运行函数
    func run(rootPath: String = "./mnt") -> Bool {
        let startTotal = Date()
        
        print("🚀 开始执行 Atlas 数据处理...")
        
        guard scanRecordsFiles(rootPath: rootPath) else {
            print("❌ 未找到文件，退出")
            return false
        }
        
        collectAllParameters()
        buildFinalData()
        
        let endTotal = Date()
        let duration = endTotal.timeIntervalSince(startTotal)
        
        print("\n✅ 处理完成")
        print("=== 总处理耗时: \(String(format: "%.3f", duration))s ===")
        print("📊 统计信息:")
        print("   - 处理文件数: \(recordsFiles.count)")
        print("   - 属性参数: \(sortedAttrNames.count)")
        print("   - 测量参数: \(sortedMeasureNames.count)")
        print("   - 总参数: \(allParamNames.count)")
        
        let failInfo = extractFailInfo()
        if !failInfo.isEmpty {
            print("⚠️  失败记录: \(failInfo.count) 条")
        }
        
        return true
    }
    
    // MARK: - 辅助方法
    
    func saveOutput(outputDir: String = "./mnt") -> String? {
        let start = Date()
        
        guard !finalData.isEmpty else {
            print("❌ 没有数据可保存")
            return nil
        }
        
        let outputFilename = "AtlasCombineData_MultiRow_\(timestamp).csv"
        let outputPath = (outputDir as NSString).appendingPathComponent(outputFilename)
        
        print("💾 保存文件到: \(outputPath)")
        
        do {
            let csvContent = finalData.map { row in
                row.map { cell in
                    // CSV转义处理
                    if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                        let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                        return "\"\(escaped)\""
                    }
                    return cell
                }.joined(separator: ",")
            }.joined(separator: "\n")
            
            try csvContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
            
            // 验证文件
            let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            let end = Date()
            let duration = end.timeIntervalSince(start)
            
            print("✅ 文件保存成功")
            print("   - 文件大小: \(String(format: "%.2f", Double(fileSize) / 1024.0)) KB")
            print("   - 总行数: \(finalData.count)")
            print("   - 保存耗时: \(String(format: "%.3f", duration))s")
            
            return outputPath
            
        } catch {
            print("❌ 无法创建输出文件: \(error)")
            return nil
        }
    }
    
    func saveOutputPlus(outputDir: String = "./mnt") -> String? {
        let start = Date()
        
        guard !finalDataPlus.isEmpty else {
            print("❌ 没有Plus数据可保存")
            return nil
        }
        
        let outputFilename = "AtlasCombineData_MultiRow_Plus_\(timestamp).csv"
        let outputPath = (outputDir as NSString).appendingPathComponent(outputFilename)
        
        print("💾 保存Plus文件到: \(outputPath)")
        
        do {
            let csvContent = finalDataPlus.map { row in
                row.map { cell in
                    // CSV转义处理
                    if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                        let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                        return "\"\(escaped)\""
                    }
                    return cell
                }.joined(separator: ",")
            }.joined(separator: "\n")
            
            try csvContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
            
            let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            let end = Date()
            let duration = end.timeIntervalSince(start)
            
            print("✅ Plus文件保存成功")
            print("   - 文件大小: \(String(format: "%.2f", Double(fileSize) / 1024.0)) KB")
            print("   - 总行数: \(finalDataPlus.count)")
            print("   - 保存耗时: \(String(format: "%.3f", duration))s")
            
            return outputPath
            
        } catch {
            print("❌ 无法创建Plus输出文件: \(error)")
            return nil
        }
    }
    
    // MARK: - 异步版本（适合UI应用）
    func runAsync(rootPath: String = "./mnt", 
                  progress: ((Float, String) -> Void)? = nil,
                  completion: @escaping (Bool, String?, Error?) -> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let start = Date()
                
                // 扫描文件
                progress?(0.0, "正在扫描文件...")
                guard self.scanRecordsFiles(rootPath: rootPath) else {
                    throw NSError(domain: "AtlasDataProcessor", 
                                code: 404, 
                                userInfo: [NSLocalizedDescriptionKey: "未找到文件"])
                }
                
                progress?(0.2, "正在处理 \(self.recordsFiles.count) 个文件...")
                
                // 收集参数
                self.collectAllParameters()
                progress?(0.6, "正在构建数据表...")
                
                // 构建数据
                self.buildFinalData()
                
                let end = Date()
                let duration = end.timeIntervalSince(start)
                
                let message = """
                处理完成！
                - 文件数: \(self.recordsFiles.count)
                - 参数数: \(self.allParamNames.count)
                - 耗时: \(String(format: "%.2f", duration))s
                """
                
                DispatchQueue.main.async {
                    completion(true, message, nil)
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
            }
        }
    }
    
    // MARK: - 数据分析方法
    
    func getStatistics() -> [String: Any] {
        let failInfo = extractFailInfo()
        
        return [
            "total_files": recordsFiles.count,
            "total_rows": finalData.count - 4, // 减去标题行
            "attribute_params": sortedAttrNames.count,
            "measure_params": sortedMeasureNames.count,
            "total_params": allParamNames.count,
            "failure_count": failInfo.count,
            "success_rate": recordsFiles.count > 0 ? 
                Double(recordsFiles.count - failInfo.count) / Double(recordsFiles.count) * 100 : 0,
            "timestamp": timestamp
        ]
    }
    
    func getFailureSummary() -> [String] {
        let failInfo = extractFailInfo()
        
        return failInfo.map { info in
            let time = info["测试时间"] ?? "未知时间"
            let path = info["文件路径"] ?? "未知文件"
            let tests = info["失败用例列表"] ?? "无具体用例"
            
            return "\(time) | \(tests) | \(path)"
        }
    }
    
    func exportToJSON(outputDir: String) -> String? {
        let stats = getStatistics()
        let failSummary = getFailureSummary()
        
        let exportData: [String: Any] = [
            "metadata": stats,
            "failures": failSummary,
            "parameters": [
                "attributes": sortedAttrNames,
                "measures": sortedMeasureNames
            ],
            "processed_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let filename = "AtlasAnalysis_\(timestamp).json"
        let path = (outputDir as NSString).appendingPathComponent(filename)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, 
                                                    options: [.prettyPrinted, .sortedKeys])
            try jsonData.write(to: URL(fileURLWithPath: path))
            return path
        } catch {
            print("❌ JSON导出失败: \(error)")
            return nil
        }
    }
}

// MARK: - 私有扩展：文件扫描
private extension AtlasDataProcessor {
    func scanRecordsFiles(rootPath: String) -> Bool {
        let start = Date()
        
        print("开始扫描目录: \(rootPath)")
        
        func scanDirectory(_ dirPath: String) {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: dirPath),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                print("无法打开目录: \(dirPath)")
                return
            }
            
            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true,
                      fileURL.lastPathComponent == "records.csv" else {
                    continue
                }
                
                recordsFiles.append(fileURL.path)
            }
        }
        
        scanDirectory(rootPath)
        
        let end = Date()
        let duration = end.timeIntervalSince(start)
        
        print("扫描到 \(recordsFiles.count) 个文件，耗时 \(String(format: "%.3f", duration))s")
        
        return !recordsFiles.isEmpty
    }
}

// MARK: - 私有扩展：时间格式转换
private extension AtlasDataProcessor {
    func convertTimeFormat(_ timeInput: String) -> String {
        let timeStr = AtlasUtils.trim(timeInput)
        
        if timeStr.isEmpty {
            return ""
        }
        
        let formatters: [(String, DateFormatter)] = [
            // C格式: 2025-06-18 16:36:40.449000
            ("yyyy-MM-dd HH:mm:ss.SSSSSS", {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt
            }()),
            
            // A格式: Jun 18 2025 4:24:34.3390 PM
            ("MMM dd yyyy h:mm:ss.SSSS a", {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM dd yyyy h:mm:ss.SSSS a"
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt
            }()),
            
            // 中文格式: 6月 18 2025 4:24:34.3390 上午
            ("MMM dd yyyy h:mm:ss.SSSS a", {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM dd yyyy h:mm:ss.SSSS a"
                fmt.locale = Locale(identifier: "zh_CN")
                return fmt
            }()),
            
            // B格式: 6月 18 2025 4:24:34.3390 上午 (去除中文月份)
            ("M dd yyyy h:mm:ss.SSSS a", {
                let fmt = DateFormatter()
                fmt.dateFormat = "M dd yyyy h:mm:ss.SSSS a"
                fmt.locale = Locale(identifier: "en_US_POSIX")
                return fmt
            }())
        ]
        
        var cleanedTime = timeStr
        
        // 预处理：移除中文字符
        if cleanedTime.contains("月") {
            cleanedTime = cleanedTime.replacingOccurrences(of: "月", with: "")
        }
        if cleanedTime.contains("上午") {
            cleanedTime = cleanedTime.replacingOccurrences(of: "上午", with: "AM")
        }
        if cleanedTime.contains("下午") {
            cleanedTime = cleanedTime.replacingOccurrences(of: "下午", with: "PM")
        }
        
        // 移除毫秒部分（如果存在）
        if let dotRange = cleanedTime.range(of: ".") {
            cleanedTime = String(cleanedTime[..<dotRange.lowerBound])
        }
        
        // 尝试所有格式
        for (_, formatter) in formatters {
            if let date = formatter.date(from: cleanedTime) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return outputFormatter.string(from: date)
            }
        }
        
        print("时间格式转换失败: \(timeInput)")
        return timeInput
    }
}

// MARK: - 私有扩展：处理单个文件
private extension AtlasDataProcessor {
    func processSingleFile(filePath: String) -> FileProcessResult {
        var result = FileProcessResult()
        result.filePathRow[0] = filePath
        
        let rows = AtlasUtils.readCSVFile(filePath: filePath)
        if rows.isEmpty {
            return result
        }
        
        // 提取Attribute
        var attrDict: [String: String] = [:]
        var attrNamesSet: Set<String> = []
        
        for row in rows where !row.attributeName.isEmpty {
            attrNamesSet.insert(row.attributeName)
            attrDict[row.attributeName] = row.attributeValue
        }
        
        result.attrNames = Array(attrNamesSet)
        result.attrDict = attrDict
        
        // 提取Measure
        var measureDict: [String: String] = [:]
        var measureMeta: [String: [String: String]] = [:]
        var measureNamesSet: Set<String> = []
        
        for row in rows where !row.measurementValue.isEmpty {
            let fullParamName = "\(row.testName) \(row.subTestName) \(row.subSubTestName)"
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !fullParamName.isEmpty {
                measureNamesSet.insert(fullParamName)
                measureDict[fullParamName] = row.measurementValue
                
                // 存储元数据（只取第一个）
                if measureMeta[fullParamName] == nil {
                    let meta: [String: String] = [
                        "unit": row.measurementUnits,
                        "upper": row.upperLimit,
                        "lower": row.lowerLimit
                    ]
                    measureMeta[fullParamName] = meta
                }
            }
        }
        
        result.measureNames = Array(measureNamesSet)
        result.measureMeta = measureMeta
        result.measureDict = measureDict
        
        // 提取固定信息
        let sn = attrDict["PrimaryIdentity"] ?? ""
        
        var testStatus = "PASS"
        for row in rows where row.status == "FAIL" {
            testStatus = "FAIL"
            break
        }
        
        var startTime = ""
        var endTime = ""
        for row in rows {
            if !row.startTime.isEmpty && startTime.isEmpty {
                startTime = convertTimeFormat(row.startTime)
            }
            if !row.stopTime.isEmpty && endTime.isEmpty {
                endTime = convertTimeFormat(row.stopTime)
            }
            if !startTime.isEmpty && !endTime.isEmpty {
                break
            }
        }
        
        let version = attrDict["SwVersion"] ?? ""
        
        var failTests = ""
        if testStatus == "FAIL" {
            var failTestSet: Set<String> = []
            for row in rows where row.status == "FAIL" {
                let failIdentifier = "\(row.testName) \(row.subTestName) \(row.subSubTestName)"
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !failIdentifier.isEmpty {
                    failTestSet.insert(failIdentifier)
                }
            }
            failTests = failTestSet.joined(separator: "; ")
        }
        
        // 构建固定行
        result.infoRow[0] = ghConfig.site
        result.infoRow[1] = ghConfig.product
        result.infoRow[2] = sn
        result.infoRow[3] = ""
        result.infoRow[4] = ""
        result.infoRow[5] = ""
        result.infoRow[6] = ghConfig.stationId
        result.infoRow[7] = testStatus
        result.infoRow[8] = startTime
        result.infoRow[9] = endTime
        result.infoRow[10] = version
        result.infoRow[11] = failTests
        
        return result
    }
}

// MARK: - 私有扩展：收集所有参数
private extension AtlasDataProcessor {
    func collectAllParameters() {
        let start = Date()
        
        print("开始单线程处理...")
        
        // 顺序处理每个文件（单线程）
        for filePath in recordsFiles {
            let result = processSingleFile(filePath: filePath)
            fileResults.append(result)
            
            // 合并参数名
            for attr in result.attrNames {
                allAttributeNames.insert(attr)
            }
            for measure in result.measureNames {
                allMeasureNames.insert(measure)
            }
            
            // 合并元数据
            for (key, meta) in result.measureMeta {
                if measureMetaDict[key] == nil {
                    measureMetaDict[key] = meta
                }
            }
        }
        
        // 排序参数
        sortedAttrNames = allAttributeNames.sorted()
        sortedMeasureNames = allMeasureNames.sorted()
        
        // 合并所有参数名
        allParamNames = sortedAttrNames
        allParamNames.append(contentsOf: sortedMeasureNames)
        
        // 生成单位/上下限行
        let totalParamsCount = sortedAttrNames.count + sortedMeasureNames.count
        unitRow = Array(repeating: "", count: totalParamsCount)
        upperLimitRow = Array(repeating: "", count: totalParamsCount)
        lowerLimitRow = Array(repeating: "", count: totalParamsCount)
        
        // Attribute部分为空（保持原有位置）
        for i in 0..<sortedAttrNames.count {
            unitRow[i] = ""
            upperLimitRow[i] = ""
            lowerLimitRow[i] = ""
        }
        
        // Measure部分
        for i in 0..<sortedMeasureNames.count {
            let param = sortedMeasureNames[i]
            let idx = sortedAttrNames.count + i
            
            if let meta = measureMetaDict[param] {
                unitRow[idx] = meta["unit"] ?? ""
                upperLimitRow[idx] = meta["upper"] ?? ""
                lowerLimitRow[idx] = meta["lower"] ?? ""
                // #if DEBUG
                // print("   - Measure参数[\(i)] \(param): unit=\(meta["unit"] ?? ""), upper=\(meta["upper"] ?? ""), lower=\(meta["lower"] ?? "")")
                // #endif
            }
        }
        
        let end = Date()
        let duration = end.timeIntervalSince(start)
        
        print("单线程处理耗时: \(String(format: "%.3f", duration))s")
        print("属性参数数量: \(sortedAttrNames.count)")
        print("测量参数数量: \(sortedMeasureNames.count)")
    }
}

// MARK: - 私有扩展：构建最终数据
private extension AtlasDataProcessor {
    func buildFinalData() {
        let start = Date()
        
        let totalCols = fixedColumns + allParamNames.count
        
        // 构建标题行
        var headerRow: [String] = [
            "site", "Product", "SerialNumber", "Special Build Name",
            "Special Build Description", "Unit Number", "Station ID",
            "Test Pass/Fail Status", "StartTime", "EndTime", "Version",
            "List of Failing Tests"
        ]
        headerRow.append(contentsOf: allParamNames)
        
        // 构建plus版的标题行（包含文件路径）
        var headerRowPlus = headerRow
        headerRowPlus.insert(" ", at: 12) // 在"List of Failing Tests"之前
        
        // 构建上限行
        var upperRow: [String] = ["Upper Limit ----->"]
        upperRow.append(contentsOf: Array(repeating: "", count: 11))
        upperRow.append(contentsOf: upperLimitRow)
        
        var upperRowPlus: [String] = ["Upper Limit ----->"]
        upperRowPlus.append(contentsOf: Array(repeating: "", count: 12))
        upperRowPlus.append(contentsOf: upperLimitRow)
        
        // 构建下限行
        var lowerRow: [String] = ["Lower Limit ----->"]
        lowerRow.append(contentsOf: Array(repeating: "", count: 11))
        lowerRow.append(contentsOf: lowerLimitRow)
        
        var lowerRowPlus: [String] = ["Lower Limit ----->"]
        lowerRowPlus.append(contentsOf: Array(repeating: "", count: 12))
        lowerRowPlus.append(contentsOf: lowerLimitRow)
        
        // 构建单位行
        var unitRowFull: [String] = ["Measurement Unit ----->"]
        unitRowFull.append(contentsOf: Array(repeating: "", count: 11))
        unitRowFull.append(contentsOf: unitRow)
        
        var unitRowPlus: [String] = ["Measurement Unit ----->"]
        unitRowPlus.append(contentsOf: Array(repeating: "", count: 12))
        unitRowPlus.append(contentsOf: unitRow)
        
        // 清空并初始化最终数据
        finalData.removeAll()
        finalDataPlus.removeAll()
        
        // 添加空行（原始代码中有）
        finalData.append(Array(repeating: "", count: totalCols))
        
        // 添加标题行
        finalData.append(headerRow)
        finalData.append(upperRow)
        finalData.append(lowerRow)
        finalData.append(unitRowFull)
        
        finalDataPlus.append(headerRowPlus)
        finalDataPlus.append(upperRowPlus)
        finalDataPlus.append(lowerRowPlus)
        finalDataPlus.append(unitRowPlus)
        
        // 添加数据行
        for result in fileResults {
            var row: [String] = []
            var rowPlus: [String] = []
            
            // 固定列
            for i in 0..<fixedColumns {
                let value = i < result.infoRow.count ? result.infoRow[i] : ""
                row.append(value)
                rowPlus.append(value)
            }
            
            // 文件路径（仅plus版）
            let filePath = result.filePathRow.isEmpty ? "" : result.filePathRow[0]
            rowPlus.append(filePath)
            
            // Attribute值
            for attrName in sortedAttrNames {
                let value = result.attrDict[attrName] ?? ""
                row.append(value)
                rowPlus.append(value)
            }
            
            // Measure值
            for measureName in sortedMeasureNames {
                let value = result.measureDict[measureName] ?? ""
                row.append(value)
                rowPlus.append(value)
            }
            
            finalData.append(row)
            finalDataPlus.append(rowPlus)
        }
        
        let end = Date()
        let duration = end.timeIntervalSince(start)
        
        print("构建最终数据耗时: \(String(format: "%.3f", duration))s")
        print("标准数据行数: \(finalData.count)")
        print("Plus数据行数: \(finalDataPlus.count)")
        print("每行列数: \(totalCols)")
    }
}

// MARK: - 扩展：提取失败信息
extension AtlasDataProcessor {
    func extractFailInfo() -> [[String: String]] {
        var failInfoList: [[String: String]] = []
        
        guard finalDataPlus.count > 4 else {
            return failInfoList
        }
        
        let headerRow = finalDataPlus[0]
        
        guard let statusColIdx = headerRow.firstIndex(of: "Test Pass/Fail Status"),
              let failTestsColIdx = headerRow.firstIndex(of: "List of Failing Tests"),
              let filePathColIdx = headerRow.firstIndex(of: "file_path"),
              let endTimeColIdx = headerRow.firstIndex(of: "EndTime") else {
            print("警告：未找到必要的列名")
            return failInfoList
        }
        
        // 从第4行开始
        for i in 4..<finalDataPlus.count {
            let row = finalDataPlus[i]
            
            guard row.count > statusColIdx else { continue }
            
            if row[statusColIdx] == "FAIL" {
                let failInfo: [String: String] = [
                    "测试时间": row.count > endTimeColIdx ? row[endTimeColIdx] : "000000",
                    "文件路径": row.count > filePathColIdx ? row[filePathColIdx] : "未知文件路径",
                    "失败用例列表": row.count > failTestsColIdx ? row[failTestsColIdx] : "无具体失败用例"
                ]
                
                failInfoList.append(failInfo)
            }
        }
        
        return failInfoList
    }
}

// MARK: - 扩展：支持 SwiftUI/Cocoa 的数据绑定
extension AtlasDataProcessor {
    
    struct ProcessStatus: Identifiable {
        let id = UUID()
        let fileName: String
        let status: String
        let progress: Double
        let message: String
    }
    
    class ObservableProcessor: ObservableObject {
        @Published var isProcessing = false
        @Published var progress: Float = 0.0
        @Published var statusMessage = ""
        @Published var statistics: [String: Any] = [:]
        @Published var failures: [String] = []
        
        private let processor = AtlasDataProcessor()
        
        func processDirectory(_ path: String) {
            isProcessing = true
            statusMessage = "开始处理..."
            
            processor.runAsync(rootPath: path) { [weak self] progressValue, message in
                DispatchQueue.main.async {
                    self?.progress = progressValue
                    self?.statusMessage = message
                }
            } completion: { [weak self] success, message, error in
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    
                    if success {
                        self?.statusMessage = message ?? "处理完成"
                        self?.statistics = self?.processor.getStatistics() ?? [:]
                        self?.failures = self?.processor.getFailureSummary() ?? []
                    } else {
                        self?.statusMessage = error?.localizedDescription ?? "处理失败"
                    }
                }
            }
        }
    }
}

// MARK: - 扩展：为 UI 提供便利方法
extension AtlasDataProcessor {
    
    // 获取时间戳（公开版本）
    func getTimestamp() -> String {
        return timestamp
    }
    
    // 获取最终数据
    func getFinalData() -> [[String]] {
        return finalData
    }
    
    // 获取最终数据 Plus 版本
    func getFinalDataPlus() -> [[String]] {
        return finalDataPlus
    }
    
    // 获取处理状态摘要
    func getProcessingSummary() -> [String: Any] {
        return [
            "files_processed": recordsFiles.count,
            "parameters_found": allParamNames.count,
            "failures_detected": extractFailInfo().count,
            "processing_timestamp": timestamp
        ]
    }
}