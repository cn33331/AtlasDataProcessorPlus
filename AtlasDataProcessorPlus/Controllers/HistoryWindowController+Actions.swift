// HistoryWindowController+Actions.swift
// 负责按钮动作和业务逻辑

import Cocoa

extension HistoryWindowController {
    
    // MARK: - 按钮动作
    @objc func browseButtonClicked() {
        #if DEBUG
        print("📂 HistoryWindowController: 浏览按钮被点击")
        #endif
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择目录"
        openPanel.message = "请选择包含 records.csv 文件的目录"
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            #if DEBUG
            print("📂 HistoryWindowController: 文件选择面板响应: \(response == .OK ? "OK" : "Cancel")")
            #endif
            guard response == .OK, let url = openPanel.url else { return }
            self?.pathTextField.stringValue = url.path
            #if DEBUG
            print("📂 HistoryWindowController: 选择的目录: \(url.path)")
            #endif
        }
    }
    
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
    
    @objc func saveCSVButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "AtlasCombineData_\(processor.getTimestamp()).csv"
        savePanel.message = "选择保存 CSV 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                // 构建 CSV 内容
                let csvContent = self?.processedData.map { row in
                    row.map { cell in
                        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                            let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        return cell
                    }.joined(separator: ",")
                }.joined(separator: "\n")
                
                try csvContent?.write(to: url, atomically: true, encoding: .utf8)
                self?.showAlert(title: "成功", message: "CSV 文件已保存到: \(url.path)")
                
            } catch {
                self?.showAlert(title: "保存失败", message: "无法保存文件: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func saveCSVPlusButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "AtlasCombineDataPlus_\(processor.getTimestamp()).csv"
        savePanel.message = "选择保存 CSV Plus 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                // 构建 CSV 内容
                let csvContent = self?.processedDataPlus.map { row in
                    row.map { cell in
                        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                            let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        return cell
                    }.joined(separator: ",")
                }.joined(separator: "\n")
                
                try csvContent?.write(to: url, atomically: true, encoding: .utf8)
                self?.showAlert(title: "成功", message: "CSV Plus 文件已保存到: \(url.path)")
                
            } catch {
                self?.showAlert(title: "保存失败", message: "无法保存文件: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func exportJSONButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "AtlasCombineData_\(processor.getTimestamp()).json"
        savePanel.message = "选择导出 JSON 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                // 构建 JSON 内容
                let jsonData = try JSONSerialization.data(withJSONObject: self?.statistics ?? [:], options: .prettyPrinted)
                try jsonData.write(to: url)
                self?.showAlert(title: "成功", message: "JSON 文件已导出到: \(url.path)")
                
            } catch {
                self?.showAlert(title: "导出失败", message: "无法导出文件: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 业务逻辑
    func startProcessing(path: String) {
        guard !isProcessing else { return }
        
        isProcessing = true
        processButton.isEnabled = false
        browseButton.isEnabled = false
        statusLabel.stringValue = "正在处理数据..."
        
        // 重置按钮状态
        saveCSVButton.isEnabled = false
        saveCSVPlusButton.isEnabled = false
        exportJSONButton.isEnabled = false
        
        // 创建新的处理器实例
        processor = AtlasDataProcessor()
        
        // 异步处理
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let processor = self.processor else { return }
            
            let success = processor.run(rootPath: path)
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processButton.isEnabled = true
                self.browseButton.isEnabled = true
                
                if success {
                    self.statusLabel.stringValue = "处理完成"
                    
                    // 获取数据
                    self.processedData = processor.getFinalData()
                    self.processedDataPlus = processor.getFinalDataPlus()
                    
                    // 获取统计信息
                    self.statistics = processor.getStatistics()
                    self.failures = processor.getFailureSummary()
                    
                    // 初始化筛选数据
                    self.filteredFailures = self.failures
                    
                    // 对失败记录按文件路径分组
                    self.groupFailuresByFilePath()
                    
                    // 重置筛选和排序状态
                    self.filters.removeAll()
                    self.sortColumn = nil
                    
                    // 暂时允许空选择
                    self.tableView.allowsEmptySelection = true
                    
                    // 更新UI
                    self.tableView.reloadData()
                    
                    // 清除选择
                    self.tableView.deselectAll(nil)
                    
                    // 恢复不允许空选择
                    self.tableView.allowsEmptySelection = false
                    
                    // 启用保存按钮
                    self.saveCSVButton.isEnabled = !self.processedData.isEmpty
                    self.saveCSVPlusButton.isEnabled = !self.processedDataPlus.isEmpty
                    self.exportJSONButton.isEnabled = true
                    
                    // 显示成功信息
                    let fileCount = self.statistics["total_files"] as? Int ?? 0
                    let paramCount = self.statistics["total_params"] as? Int ?? 0
                    let failureCount = self.statistics["failure_count"] as? Int ?? 0
                    
                    if failureCount > 0 {
                        self.showAlert(title: "处理完成", 
                                     message: """
                                     处理完成！
                                     文件数: \(fileCount)
                                     参数数: \(paramCount)
                                     发现 \(failureCount) 条失败记录
                                     """)
                    } else {
                        self.showAlert(title: "处理完成", 
                                     message: """
                                     处理完成！
                                     文件数: \(fileCount)
                                     参数数: \(paramCount)
                                     所有测试都通过 ✓
                                     """)
                    }
                    
                } else {
                    self.statusLabel.stringValue = "处理失败"
                    self.showAlert(title: "处理失败", message: "无法处理数据，请检查目录结构和文件权限")
                }
            }
        }
    }
    
    // 展开所有分组
    @objc func expandAllGroups() {
        print("👆 展开所有按钮被点击")
        print("分组数量: \(groupedFailures.count)")
        
        for groupIndex in 0..<groupedFailures.count {
            expandedGroups.insert(groupIndex)
        }
        
        print("展开后的分组: \(expandedGroups)")
        
        // 暂时允许空选择，避免重新加载数据时自动选择行
        tableView.allowsEmptySelection = true
        tableView.reloadData()
        tableView.deselectAll(nil)
        tableView.allowsEmptySelection = false
    }
    
    // 折叠所有分组
    @objc func collapseAllGroups() {
        print("👆 折叠所有按钮被点击")
        expandedGroups.removeAll()
        
        // 暂时允许空选择，避免重新加载数据时自动选择行
        tableView.allowsEmptySelection = true
        tableView.reloadData()
        tableView.deselectAll(nil)
        tableView.allowsEmptySelection = false
    }
    
    // 显示警告框
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    
    // 按文件路径分组失败记录
    func groupFailuresByFilePath() {
        var filePathToFailures: [String: [String]] = [:]
        
        // 遍历所有失败记录
        for failure in failures {
            let components = failure.components(separatedBy: " | ")
            let filePath = components.count > 2 ? components[2] : "未知文件"
            
            // 添加到对应文件路径的数组中
            if filePathToFailures[filePath] == nil {
                filePathToFailures[filePath] = []
            }
            filePathToFailures[filePath]?.append(failure)
        }
        
        // 转换为GroupedFailure数组
        groupedFailures = filePathToFailures.map { GroupedFailure(filePath: $0.key, items: $0.value) }
        
        // 按文件路径排序
        groupedFailures.sort { $0.filePath < $1.filePath }
        
        // 重置展开状态
        expandedGroups.removeAll()
    }
    
    // 打开文件路径
    @objc func openFilePath(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: String],
              let filePath = data["filePath"] else { return }
        
        let url = URL(fileURLWithPath: filePath)

        // 允许 filePath 本身就是目录：
        // - 如果是目录：直接打开该目录
        // - 如果是文件：打开其所在目录
        var isDir: ObjCBool = false
        let fileManager = FileManager.default
        let resolvedDirectoryURL: URL

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            resolvedDirectoryURL = url
        } else {
            resolvedDirectoryURL = url.deletingLastPathComponent()
        }

        #if DEBUG
        print("📂 openFilePath 被点击")
        print("  filePath: \(filePath)")
        print("  directoryToOpen: \(resolvedDirectoryURL.path)")
        #endif

        // 直接打开 Finder 目录（避免只“选择”目录导致看起来像没打开）
        // 注意：你的 SDK 里没有 activateFileViewer，因此这里使用 open(_:)
        NSWorkspace.shared.open(resolvedDirectoryURL)
    }
    
    // 切换分组详情显示
    @objc func toggleGroupDetails(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Int],
              let groupIndex = data["groupIndex"] else { return }

        #if DEBUG
        print("🧩 toggleGroupDetails 被点击，groupIndex=\(groupIndex)")
        print("  当前展开状态: \(expandedGroups.contains(groupIndex))")
        #endif
        
        // 切换分组展开/折叠状态
        if expandedGroups.contains(groupIndex) {
            expandedGroups.remove(groupIndex)
        } else {
            expandedGroups.insert(groupIndex)
        }
        tableView.reloadData()

        #if DEBUG
        print("  切换后展开状态: \(expandedGroups.contains(groupIndex))")
        #endif
    }
    
    // 打开文件所在路径
    func openFileLocation(filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        let directoryURL = fileURL.deletingLastPathComponent()
        
        // 使用 Finder 打开目录
        NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
    }
    
    // 删除本组失败记录
    @objc func deleteGroup(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Int],
              let groupIndex = data["groupIndex"] else { return }
        
        #if DEBUG
        print("🗑️ deleteGroup 被点击，groupIndex=\(groupIndex)")
        #endif
        
        // 确认删除
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除这一组失败记录吗？此操作不可恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self else { return }
            
            if response == .alertFirstButtonReturn {
                // 用户确认删除
                #if DEBUG
                print("  用户确认删除分组 \(groupIndex)")
                #endif
                
                // 从groupedFailures中删除该分组
                if groupIndex < self.groupedFailures.count {
                    self.groupedFailures.remove(at: groupIndex)
                    
                    // 更新expandedGroups，移除该分组的展开状态
                    self.expandedGroups.remove(groupIndex)
                    
                    // 调整其他分组的展开状态索引
                    var newExpandedGroups: Set<Int> = []
                    for index in self.expandedGroups {
                        if index > groupIndex {
                            newExpandedGroups.insert(index - 1)
                        } else if index < groupIndex {
                            newExpandedGroups.insert(index)
                        }
                    }
                    self.expandedGroups = newExpandedGroups
                    
                    // 重新加载表格数据
                    self.tableView.reloadData()
                    
                    #if DEBUG
                    print("  分组删除完成，剩余分组数: \(self.groupedFailures.count)")
                    #endif
                }
            } else {
                #if DEBUG
                print("  用户取消删除")
                #endif
            }
        }
    }
    
    // 删除本条失败记录
    @objc func deleteItem(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Int],
              let groupIndex = data["groupIndex"],
              let itemIndex = data["itemIndex"] else { return }
        
        #if DEBUG
        print("🗑️ deleteItem 被点击，groupIndex=\(groupIndex), itemIndex=\(itemIndex)")
        #endif
        
        // 确认删除
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除这一条失败记录吗？此操作不可恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self else { return }
            
            if response == .alertFirstButtonReturn {
                // 用户确认删除
                #if DEBUG
                print("  用户确认删除项目 groupIndex=\(groupIndex), itemIndex=\(itemIndex)")
                #endif
                
                // 检查分组和项目索引是否有效
                if groupIndex < self.groupedFailures.count {
                    var group = self.groupedFailures[groupIndex]
                    
                    if itemIndex < group.items.count {
                        // 从分组中删除该项目
                        group.items.remove(at: itemIndex)
                        
                        // 如果分组为空，删除整个分组
                        if group.items.isEmpty {
                            self.groupedFailures.remove(at: groupIndex)
                            
                            // 更新expandedGroups
                            self.expandedGroups.remove(groupIndex)
                            var newExpandedGroups: Set<Int> = []
                            for index in self.expandedGroups {
                                if index > groupIndex {
                                    newExpandedGroups.insert(index - 1)
                                } else if index < groupIndex {
                                    newExpandedGroups.insert(index)
                                }
                            }
                            self.expandedGroups = newExpandedGroups
                        } else {
                            // 更新分组
                            self.groupedFailures[groupIndex] = group
                        }
                        
                        // 重新加载表格数据
                        self.tableView.reloadData()
                        
                        #if DEBUG
                        print("  项目删除完成")
                        #endif
                    }
                }
            } else {
                #if DEBUG
                print("  用户取消删除")
                #endif
            }
        }
    }
    
    // 删除全局相同失败用例的记录
    @objc func deleteGlobalSameFailure(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Int],
              let groupIndex = data["groupIndex"],
              let itemIndex = data["itemIndex"] else { return }
        
        #if DEBUG
        print("🗑️ deleteGlobalSameFailure 被点击，groupIndex=\(groupIndex), itemIndex=\(itemIndex)")
        #endif
        
        // 获取当前失败记录的失败用例名称
        guard groupIndex < groupedFailures.count else { return }
        let group = groupedFailures[groupIndex]
        guard itemIndex < group.items.count else { return }
        let failure = group.items[itemIndex]
        let components = failure.components(separatedBy: " | ")
        guard components.count > 1 else { return }
        let failureCase = components[1]
        
        // 确认删除
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除全局所有包含相同失败用例的记录吗？此操作不可恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        alert.beginSheetModal(for: window!) { [weak self] response in
            guard let self = self else { return }
            
            if response == .alertFirstButtonReturn {
                // 用户确认删除
                #if DEBUG
                print("  用户确认删除全局相同失败用例: \(failureCase)")
                #endif
                
                // 遍历所有分组，删除包含相同失败用例的记录
                var groupsToRemove: [Int] = []
                
                for (currentGroupIndex, var currentGroup) in self.groupedFailures.enumerated() {
                    // 筛选出不包含相同失败用例的记录
                    let filteredItems = currentGroup.items.filter { item in
                        let itemComponents = item.components(separatedBy: " | ")
                        return itemComponents.count <= 1 || itemComponents[1] != failureCase
                    }
                    
                    if filteredItems.count == 0 {
                        // 如果分组为空，标记为删除
                        groupsToRemove.append(currentGroupIndex)
                    } else if filteredItems.count != currentGroup.items.count {
                        // 更新分组
                        currentGroup.items = filteredItems
                        self.groupedFailures[currentGroupIndex] = currentGroup
                    }
                }
                
                // 按从后往前的顺序删除分组，避免索引错乱
                for groupIndexToRemove in groupsToRemove.sorted(by: >) {
                    self.groupedFailures.remove(at: groupIndexToRemove)
                    
                    // 更新expandedGroups
                    self.expandedGroups.remove(groupIndexToRemove)
                    var newExpandedGroups: Set<Int> = []
                    for index in self.expandedGroups {
                        if index > groupIndexToRemove {
                            newExpandedGroups.insert(index - 1)
                        } else if index < groupIndexToRemove {
                            newExpandedGroups.insert(index)
                        }
                    }
                    self.expandedGroups = newExpandedGroups
                }
                
                // 重新加载表格数据
                self.tableView.reloadData()
                
                #if DEBUG
                print("  全局相同失败用例删除完成")
                #endif
            } else {
                #if DEBUG
                print("  用户取消删除")
                #endif
            }
        }
    }
    
    // MARK: - 静态方法
    static func createAndShow() -> HistoryWindowController {
        #if DEBUG
        print("🚀 HistoryWindowController: createAndShow 被调用")
        #endif
        let windowController = HistoryWindowController(window: NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        ))
        windowController.showWindow(nil)
        return windowController
    }
}