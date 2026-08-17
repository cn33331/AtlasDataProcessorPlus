// HistoryWindowController+Actions.swift
// 按钮动作、业务逻辑、数据处理

import Cocoa

extension HistoryWindowController {
    
    // MARK: - 浏览按钮
    @objc func browseButtonClicked() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择目录"
        openPanel.message = "请选择包含 records.csv 文件的目录"
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.pathTextField.stringValue = url.path
        }
    }
    
    // MARK: - 处理数据
    @objc func processButtonClicked() {
        let path = pathTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            showAlert(title: "错误", message: "请先选择数据目录")
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            showAlert(title: "错误", message: "目录不存在")
            return
        }
        startProcessing(path: path)
    }
    
    func startProcessing(path: String) {
        guard !isProcessing else { return }
        
        isProcessing = true
        processButton.isEnabled = false
        browseButton.isEnabled = false
        statusLabel.stringValue = "正在处理数据..."
        progressIndicator.startAnimation(nil)
        
        reparseButton.isEnabled = false
        exportCSVButton.isEnabled = false
        currentFailFilterButton.isEnabled = false
        
        processor = AtlasDataProcessor()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let processor = self.processor else { return }
            let success = processor.run(rootPath: path)
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processButton.isEnabled = true
                self.browseButton.isEnabled = true
                self.progressIndicator.stopAnimation(nil)
                
                if success {
                    self.processedDataPlus = processor.getFinalDataPlus()
                    
                    // 提取上限/下限行（processedDataPlus[1] 和 [2]）
                    if self.processedDataPlus.count > 2 {
                        self.upperLimitRow = self.processedDataPlus[1]
                        self.lowerLimitRow = self.processedDataPlus[2]
                    }
                    
                    self.statistics = processor.getStatistics()
                    
                    let snColumnName = AppConfig.shared.tableConfig["sn"] ?? ""
                    let channelColumnName = AppConfig.shared.tableConfig["channel"] ?? ""
                    let sBuildColumnName = AppConfig.shared.tableConfig["s_build"] ?? ""
                    self.failures = processor.getFailureSummary(
                        snColumnName: snColumnName,
                        channelColumnName: channelColumnName,
                        sBuildColumnName: sBuildColumnName
                    )
                    
                    // 构建扁平记录
                    self.buildRecords()
                    self.applyFilters()
                    self.updateSlotStats()
                    self.updateSBuildStats()
                    
                    self.statusLabel.stringValue = "处理完成"
                    self.reparseButton.isEnabled = true
                    self.exportCSVButton.isEnabled = !self.allRecords.isEmpty
                    self.currentFailFilterButton.isEnabled = !self.failures.isEmpty
                    
                    let fileCount = self.statistics["total_files"] as? Int ?? 0
                    let paramCount = self.statistics["total_params"] as? Int ?? 0
                    let failureCount = self.statistics["failure_count"] as? Int ?? 0
                    
                    if failureCount > 0 {
                        self.showAlert(title: "处理完成",
                            message: "文件数: \(fileCount)\n参数数: \(paramCount)\n发现 \(failureCount) 条失败记录")
                    } else {
                        self.showAlert(title: "处理完成",
                            message: "文件数: \(fileCount)\n参数数: \(paramCount)\n所有测试都通过 ✓")
                    }
                } else {
                    self.statusLabel.stringValue = "处理失败"
                    self.showAlert(title: "处理失败", message: "无法处理数据，请检查目录结构和文件权限")
                }
            }
        }
    }
    
    // MARK: - 构建扁平记录
    private func buildRecords() {
        allRecords.removeAll()
        
        guard processedDataPlus.count > 4 else { return }
        
        let headerRow = processedDataPlus[0]
        
        // 查找关键列索引（动态从表头查找，保留原索引为 fallback）
        let snColName = AppConfig.shared.tableConfig["sn"] ?? "PrimaryIdentity"
        let channelColName = AppConfig.shared.tableConfig["channel"] ?? ""
        let sBuildColName = AppConfig.shared.tableConfig["s_build"] ?? "S_BUILD"
        
        var snIndex = headerRow.firstIndex(of: snColName) ?? 2
        if snIndex < 0 || snIndex >= headerRow.count { snIndex = 2 }
        var channelIndex = headerRow.firstIndex(of: channelColName) ?? 5
        if channelIndex < 0 || channelIndex >= headerRow.count { channelIndex = 5 }
        var sBuildIndex = headerRow.firstIndex(of: sBuildColName) ?? 3
        if sBuildIndex < 0 || sBuildIndex >= headerRow.count { sBuildIndex = 3 }
        
        // 固定列也改为动态查找（原来硬编码 7/9/11/12/13）
        let statusIndex = headerRow.firstIndex(of: "Test Pass/Fail Status") ?? 7
        let timeIndex = headerRow.firstIndex(of: "EndTime") ?? 9
        let testNameIndex = headerRow.firstIndex(of: "List of Failing Tests") ?? 11
        let filePathIndex = headerRow.firstIndex(of: "file_path") ?? 12
        // 测量参数列从 file_path 之后开始
        let fixedColCount = filePathIndex + 1
        
        for i in 4..<processedDataPlus.count {
            let row = processedDataPlus[i]
            guard row.count > max(snIndex, channelIndex, sBuildIndex, statusIndex, timeIndex, testNameIndex) else { continue }
            
            let sn = snIndex < row.count ? row[snIndex] : ""
            let slotID = channelIndex < row.count ? row[channelIndex] : ""
            let sBuild = sBuildIndex < row.count ? row[sBuildIndex] : ""
            let status = statusIndex < row.count ? row[statusIndex] : ""
            let testTime = timeIndex < row.count ? row[timeIndex] : ""
            let testName = testNameIndex < row.count ? row[testNameIndex] : ""
            
            // 测量数据摘要：取属性列和测量列中的非空值
            var measurementParts: [String] = []
            for j in fixedColCount..<row.count {
                let val = row[j].trimmingCharacters(in: .whitespaces)
                if !val.isEmpty {
                    measurementParts.append(val)
                }
            }
            let measurementData = measurementParts.joined(separator: " | ")
            
            let record = TestRecord(
                index: i - 3,  // 1-based, skip header rows
                sn: sn,
                slotID: slotID,
                sBuild: sBuild,
                status: status,
                testTime: testTime,
                testName: testName,
                measurementData: measurementData,
                filePath: filePathIndex < row.count ? row[filePathIndex] : "",
                rowData: row,
                headerRow: headerRow
            )
            allRecords.append(record)
        }
    }
    
    // MARK: - 过滤与排序
    func applyFilters() {
        var records = allRecords

        // 屏蔽处理优先：将匹配的 FAIL 记录改为 PASS（在状态过滤之前执行）
        for i in 0..<records.count {
            if records[i].status == "FAIL" {
                let isBlocked = (!records[i].testName.isEmpty && blockedFailures.contains(records[i].testName))
                    || (!records[i].sn.isEmpty && sessionBlockedSNs.contains(records[i].sn))
                    || (!records[i].slotID.isEmpty && sessionBlockedChannels.contains(records[i].slotID))
                    || (!records[i].sBuild.isEmpty && sessionBlockedSBuilds.contains(records[i].sBuild))
                if isBlocked {
                    records[i].status = "PASS"
                }
            }
        }

        // 状态过滤（基于屏蔽后的 status，与主表格 Status 列一致）
        if statusFilter == "pass" {
            records = records.filter { $0.status == "PASS" }
        } else if statusFilter == "fail" {
            records = records.filter { $0.status == "FAIL" }
        }

        // SLOT 排除过滤（只保留未被排除的）
        if !excludedSlots.isEmpty {
            records = records.filter { !excludedSlots.contains($0.slotID) && !excludedSlots.contains($0.slotID.isEmpty ? "?" : $0.slotID) }
        }

        // S_BUILD 排除过滤
        if !excludedSBuilds.isEmpty {
            records = records.filter { !excludedSBuilds.contains($0.sBuild) && !excludedSBuilds.contains($0.sBuild.isEmpty ? "?" : $0.sBuild) }
        }

        // 搜索过滤（空格分隔多关键词，AND 匹配 SN/S_BUILD/测试名）
        if !searchText.isEmpty {
            records = records.filter {
                AtlasUtils.matchesAllKeywords(searchText, in: [$0.sn, $0.sBuild, $0.testName])
            }
        }

        // 日期过滤
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        if let from = dateFrom {
            records = records.filter {
                guard let date = dateFormatter.date(from: $0.testTime) else { return true }
                return date >= from
            }
        }
        if let to = dateTo {
            records = records.filter {
                guard let date = dateFormatter.date(from: $0.testTime) else { return true }
                return date <= to
            }
        }
        
        // 排序
        let ascending = sortAscending
        switch currentSortField {
        case "slot":
            // 数值排序：SlotID 通常是纯数字，字符串排序会导致 "10" < "2"
            records.sort {
                let a = Int($0.slotID)
                let b = Int($1.slotID)
                if let a = a, let b = b {
                    return ascending ? (a < b) : (a > b)
                }
                // 非数字回退到字符串比较
                return ascending ? ($0.slotID < $1.slotID) : ($0.slotID > $1.slotID)
            }
        case "sn":
            records.sort { ascending ? ($0.sn < $1.sn) : ($0.sn > $1.sn) }
        case "time":
            records.sort {
                let d0 = dateFormatter.date(from: $0.testTime) ?? Date.distantPast
                let d1 = dateFormatter.date(from: $1.testTime) ?? Date.distantPast
                return ascending ? (d0 < d1) : (d0 > d1)
            }
        default:
            records.sort { ascending ? ($0.index < $1.index) : ($0.index > $1.index) }
        }
        
        filteredRecords = records
        tableView.reloadData()
        
        let count = filteredRecords.count
        let total = allRecords.count
        let visibleFailCount = filteredRecords.filter { $0.status == "FAIL" }.count
        // 统计行反映主表格实际状态（屏蔽后 FAIL→PASS）
        let tableFailCount = records.filter { $0.status == "FAIL" }.count
        let tablePassCount = records.filter { $0.status == "PASS" }.count
        
        // 更新状态统计行
        statusSummaryLabel.stringValue = "共 \(total) 条 | PASS: \(tablePassCount) | FAIL: \(tableFailCount)"
        
        if tableFailCount > 0 && visibleFailCount == 0 {
            statusLabel.stringValue = "共 \(count) 条记录（所有失败项已屏蔽，全PASS ✓）"
        } else if count != total {
            statusLabel.stringValue = "共 \(count) 条记录（已过滤，总计 \(total) 条）"
        } else {
            statusLabel.stringValue = "共 \(count) 条记录"
        }
    }
    
    // MARK: - 状态过滤
    @objc func setStatusFilter(_ sender: NSButton) {
        switch sender.tag {
        case 0: statusFilter = "all"
        case 1: statusFilter = "pass"
        case 2: statusFilter = "fail"
        default: statusFilter = "all"
        }
        
        highlightButton(allFilterButton, active: sender.tag == 0)
        highlightButton(passFilterButton, active: sender.tag == 1)
        highlightButton(failFilterButton, active: sender.tag == 2)
        
        applyFilters()
    }
    
    // MARK: - 搜索（300ms 防抖，避免大数据量时每次按键都全量筛选）
    @objc func searchTextChanged(_ sender: NSSearchField) {
        searchText = sender.stringValue
        searchDebounceTimer?.invalidate()
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.applyFilters()
        }
    }
    
    // MARK: - 日期过滤
    @objc func dateFilterChanged(_ sender: NSDatePicker) {
        if sender == dateFromPicker {
            dateFrom = sender.dateValue
        } else {
            dateTo = sender.dateValue
        }
        applyFilters()
    }
    
    // MARK: - 快捷日期选择
    @objc func dateQuickToday() {
        let today = Calendar.current.startOfDay(for: Date())
        dateFrom = today
        dateTo = nil
        dateFromPicker.dateValue = today
        dateToPicker.dateValue = Date.distantFuture
        applyFilters()
    }
    
    @objc func dateQuick3Days() {
        let today = Calendar.current.startOfDay(for: Date())
        dateFrom = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        dateTo = nil
        dateFromPicker.dateValue = dateFrom!
        dateToPicker.dateValue = Date.distantFuture
        applyFilters()
    }
    
    @objc func dateQuick7Days() {
        let today = Calendar.current.startOfDay(for: Date())
        dateFrom = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        dateTo = nil
        dateFromPicker.dateValue = dateFrom!
        dateToPicker.dateValue = Date.distantFuture
        applyFilters()
    }
    
    @objc func dateQuickAll() {
        dateFrom = nil
        dateTo = nil
        dateFromPicker.dateValue = Date.distantPast
        dateToPicker.dateValue = Date.distantFuture
        applyFilters()
    }
    
    // MARK: - 快捷时间选择（分钟级）
    @objc func dateQuick1Hour() {
        let now = Date()
        dateFrom = Calendar.current.date(byAdding: .hour, value: -1, to: now)!
        dateTo = now
        dateFromPicker.dateValue = dateFrom!
        dateToPicker.dateValue = now
        applyFilters()
    }
    
    @objc func dateQuick6Hours() {
        let now = Date()
        dateFrom = Calendar.current.date(byAdding: .hour, value: -6, to: now)!
        dateTo = now
        dateFromPicker.dateValue = dateFrom!
        dateToPicker.dateValue = now
        applyFilters()
    }
    
    @objc func dateQuick12Hours() {
        let now = Date()
        dateFrom = Calendar.current.date(byAdding: .hour, value: -12, to: now)!
        dateTo = now
        dateFromPicker.dateValue = dateFrom!
        dateToPicker.dateValue = now
        applyFilters()
    }
    
    // MARK: - 清除所有过滤
    @objc func clearAllFilters() {
        statusFilter = "all"
        excludedSlots = []
        excludedSBuilds = []
        searchText = ""
        dateFrom = nil
        dateTo = nil
        searchField.stringValue = ""
        dateFromPicker.dateValue = Date.distantPast
        dateToPicker.dateValue = Date.distantFuture
        
        highlightButton(allFilterButton, active: true)
        highlightButton(passFilterButton, active: false)
        highlightButton(failFilterButton, active: false)
        
        applyFilters()
        updateSlotStats()
    }
    
    // MARK: - 排序
    // 排序统一由表头点击完成（HistoryWindowController+Table.swift didClick）；
    // 点击 "#" 列头可恢复原始行号顺序

    // MARK: - 导出（导出原始完整数据：表头 + 上限行 + 下限行 + 全部数据行，不经过筛选）
    @objc func saveCSVButtonClicked() {
        guard !processedDataPlus.isEmpty else {
            showAlert(title: "提示", message: "没有可导出的数据")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["csv"]
        let ts = processor?.getTimestamp()
            ?? ISO8601DateFormatter().string(from: Date())
        savePanel.nameFieldStringValue = "AtlasHistory_\(ts).csv"
        savePanel.message = "导出原始完整数据（共 \(processedDataPlus.count) 行）"

        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url, let self = self else { return }

            // 整表导出 processedDataPlus：保持原始 CSV 列结构与全部数据
            let lines = self.processedDataPlus.map { row in
                row.map { AtlasUtils.escapeCSV($0) }.joined(separator: ",")
            }
            let csvContent = lines.joined(separator: "\n")
            let success = AtlasUtils.writeCSV(csvContent, to: url, context: "导出原始数据")
            if success {
                self.showAlert(title: "成功", message: "已导出原始完整数据（\(self.processedDataPlus.count) 行）")
            }
        }
    }
    
    // MARK: - 详情弹窗
    func showDetailModal(for record: TestRecord) {
        // 尺寸按屏幕钳制（小屏显示器放不下 900×600）
        let modalSize = AtlasUtils.clampedWindowSize(preferred: NSSize(width: 900, height: 600))
        let vf = AtlasUtils.visibleFrame
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: modalSize.width, height: modalSize.height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "测试详情"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(
            width: min(700, vf.width - 40),
            height: min(400, vf.height - 40)
        )
        
        let controller = DetailModalController(record: record, upperLimitRow: upperLimitRow, lowerLimitRow: lowerLimitRow)
        window.contentViewController = controller
        
        // 使用独立窗口而非 sheet，确保可以正常关闭
        window.makeKeyAndOrderFront(nil)
        if let parentWindow = self.window {
            let parentFrame = parentWindow.frame
            let x = parentFrame.midX - modalSize.width / 2
            let y = parentFrame.midY - modalSize.height / 2
            // 钳制到屏幕可视区域内
            let vf = AtlasUtils.visibleFrame
            let clampedX = min(max(x, vf.minX), vf.maxX - modalSize.width)
            let clampedY = min(max(y, vf.minY), vf.maxY - modalSize.height)
            window.setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        }
    }
    
    // MARK: - 屏蔽管理
    @objc func showBlockFailDialog(_ sender: Any?) {
        let popover = NSPopover()
        popover.behavior = .semitransient

        let popoverController = BlockFailPopoverController()
        popoverController.blockedFailures = Array(AppConfig.shared.blockedFailures)
        popoverController.setPopover(popover)
        
        popoverController.completionHandler = { (filteredFailures: [String]?) in
            if let failures = filteredFailures {
                AppConfig.shared.blockedFailures = Set(failures)
                AppConfig.shared.saveConfigToFile()
                self.applyFilters()
            }
        }
        
        popover.contentViewController = popoverController
        
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
    
    @objc func showCurrentFailFilter(_ sender: Any) {
        var filePathToFailures: [String: [String]] = [:]
        for failure in failures {
            let components = failure.components(separatedBy: " | ")
            let filePath = components.count > 2 ? components[2] : "未知文件"
            filePathToFailures[filePath, default: []].append(failure)
        }
        
        var allFailureCases: Set<String> = []
        var failureCaseCounts: [String: Int] = [:]
        var channelToFailures: [String: [Any]] = [:]
        var snToFailures: [String: [Any]] = [:]
        var sBuildToFailures: [String: [Any]] = [:]
        var channelToFailureContentCounts: [String: [String: Int]] = [:]
        
        for (_, groupFailures) in filePathToFailures {
            guard !groupFailures.isEmpty else { continue }
            var groupFailureCases: [String] = []
            var channel = "", sn = "", sBuild = ""
            
            for (index, failure) in groupFailures.enumerated() {
                let parts = failure.components(separatedBy: " | ")
                guard parts.count >= 3 else { continue }
                let failureCase = parts[1].trimmingCharacters(in: .whitespaces)
                
                if index == 0 {
                    if parts.count >= 8 { channel = parts[7].trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 7 { sn = parts[6].trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 9 { sBuild = parts[8].trimmingCharacters(in: .whitespaces) }
                }
                
                if !failureCase.isEmpty && failureCase != "无具体用例" && !AppConfig.shared.blockedFailures.contains(failureCase) {
                    groupFailureCases.append(failureCase)
                    allFailureCases.insert(failureCase)
                }
            }
            
            guard !groupFailureCases.isEmpty else { continue }
            if !channel.isEmpty {
                channelToFailures[channel, default: []].append(groupFailureCases.count == 1 ? groupFailureCases[0] : groupFailureCases)
            }
            if !sn.isEmpty {
                snToFailures[sn, default: []].append(groupFailureCases.count == 1 ? groupFailureCases[0] : groupFailureCases)
            }
            if !sBuild.isEmpty {
                sBuildToFailures[sBuild, default: []].append(groupFailureCases.count == 1 ? groupFailureCases[0] : groupFailureCases)
            }
        }
        
        for failure in failures {
            let parts = failure.components(separatedBy: " | ")
            guard parts.count >= 3 else { continue }
            let failureCase = parts[1].trimmingCharacters(in: .whitespaces)
            if !failureCase.isEmpty && failureCase != "无具体用例" && !AppConfig.shared.blockedFailures.contains(failureCase) {
                allFailureCases.insert(failureCase)
                failureCaseCounts[failureCase, default: 0] += 1
                if parts.count >= 8 {
                    let channel = parts[7].trimmingCharacters(in: .whitespaces)
                    if !channel.isEmpty {
                        channelToFailureContentCounts[channel, default: [:]][failureCase, default: 0] += 1
                    }
                }
            }
        }
        
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        
        let filterController = CurrentFailFilterController()
        filterController.failureCases = Array(allFailureCases).sorted { failureCaseCounts[$0] ?? 0 > failureCaseCounts[$1] ?? 0 }
        filterController.failureCaseCounts = failureCaseCounts
        filterController.snToFailures = snToFailures
        filterController.failureCaseBlocked = blockedFailures  // 包含全局 + 会话屏蔽
        filterController.snBlocked = sessionBlockedSNs
        filterController.setPopover(popover)
        
        filterController.completionHandler = { [weak self] (blockedFailures, blockedSNs) in
            guard let self = self else { return }
            self.sessionBlockedFailures = blockedFailures
            self.sessionBlockedSNs = blockedSNs
            self.applyFilters()
        }
        
        popover.contentViewController = filterController
        
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        } else if let window = self.window {
            popover.show(relativeTo: window.contentView!.bounds, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    @objc func showTableConfigDialog(_ sender: Any) {
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        
        let configController = TableConfigPopoverController()
        configController.sn = AppConfig.shared.tableConfig["sn"] ?? "PrimaryIdentity"
        configController.channel = AppConfig.shared.tableConfig["channel"] ?? ""
        configController.sBuild = AppConfig.shared.tableConfig["s_build"] ?? "S_BUILD"
        configController.setPopover(popover)
        
        configController.completionHandler = { (sn, channel, sBuild) in
            var config = AppConfig.shared.tableConfig
            config["sn"] = sn
            config["channel"] = channel
            config["s_build"] = sBuild
            AppConfig.shared.tableConfig = config
            AppConfig.shared.saveConfigToFile()
        }
        
        popover.contentViewController = configController
        
        if let button = sender as? NSButton {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }
    
    // MARK: - 工具方法
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    
    static func createAndShow() -> HistoryWindowController {
        // 窗口尺寸按屏幕钳制（工厂小屏显示器放不下 1200×700）
        let winSize = AtlasUtils.clampedWindowSize(preferred: NSSize(width: 1200, height: 700))
        let windowController = HistoryWindowController(window: NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winSize.width, height: winSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        ))
        windowController.showWindow(nil)
        windowController.window?.center()
        // 窗口打开后自动开始处理数据
        DispatchQueue.main.async {
            windowController.processButtonClicked()
        }
        return windowController
    }
}