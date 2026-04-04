// CurrentFailFilterController.swift
// 用于当前失败用例筛选的弹出式面板控制器

import Cocoa

// 自定义搜索框，支持粘贴操作
class CustomSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 检查是否是 Command+V (粘贴)
        if event.modifierFlags.contains(.command) && event.keyCode == 9 {
            // 9 是 'v' 键的 keyCode
            if let pasteboardString = NSPasteboard.general.string(forType: .string) {
                // 获取当前选中的文本范围
                let selectedRange = self.currentEditor()?.selectedRange
                
                // 插入粘贴的文本
                if let editor = self.currentEditor() {
                    editor.insertText(pasteboardString)
                    return true
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

class CurrentFailFilterController: NSViewController, NSTabViewDelegate {
    
    // 标签页视图
    private var tabView: NSTabView!
    
    // 表格视图
    private var failureCaseTableView: NSTableView!
    private var snTableView: NSTableView!
    private var channelTableView: NSTableView!
    
    // 搜索框
    private var searchField: CustomSearchField!
    
    // 失败用例列表
    var failureCases: [String] = []
    
    // 失败用例出现次数统计
    var failureCaseCounts: [String: Int] = [:]
    
    // 通道号到失败用例的映射
    var channelToFailures: [String: [String]] = [:]
    
    // SN到失败用例的映射
    var snToFailures: [String: [String]] = [:]
    
    // 已屏蔽的失败用例集合
    var blockedFailures: Set<String> = []
    
    // 回调闭包
    var completionHandler: ((Set<String>) -> Void)?
    
    // 弹出式面板
    private weak var popover: NSPopover?
    
    // 设置弹出式面板引用
    func setPopover(_ popover: NSPopover) {
        self.popover = popover
    }
    
    override func loadView() {
        // 创建主视图 - 增加宽度到1000以适应长文本，高度增加到400以容纳标签页
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 400))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view
        
        // 创建布局
        setupUI()
    }
    
    private func setupUI() {
        // 标题
        let titleLabel = NSTextField(labelWithString: "当前失败用例筛选")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // 搜索框 - 使用自定义类支持粘贴操作
        searchField = CustomSearchField()
        searchField.placeholderString = "搜索失败用例，按回车定位"
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchFailureCase(_:))
        // 确保搜索框可以成为第一响应者，支持粘贴等编辑操作
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        view.addSubview(searchField)
        
        // 将搜索框设置为第一响应者，确保它可以接收键盘事件
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self.searchField)
        }
        
        // 提示标签
        let infoLabel = NSTextField(labelWithString: "勾选要屏蔽的失败用例")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // 标签页视图
        tabView = NSTabView()
        tabView.delegate = self
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        
        // 失败用例标签页
        let failureCaseTab = NSTabViewItem(identifier: "失败用例")
        failureCaseTab.label = "失败用例"
        let failureCaseView = createFailureCaseTabView()
        failureCaseTab.view = failureCaseView
        tabView.addTabViewItem(failureCaseTab)
        
        // SN标签页
        let snTab = NSTabViewItem(identifier: "SN")
        snTab.label = "SN"
        let snView = createSNTabView()
        snTab.view = snView
        tabView.addTabViewItem(snTab)
        
        // 通道号标签页
        let channelTab = NSTabViewItem(identifier: "通道号")
        channelTab.label = "通道号"
        let channelView = createChannelTabView()
        channelTab.view = channelView
        tabView.addTabViewItem(channelTab)
        
        // 按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // 全选按钮
        let selectAllButton = NSButton(title: "全选", target: self, action: #selector(selectAllFailures))
        selectAllButton.bezelStyle = NSButton.BezelStyle.rounded
        selectAllButton.font = NSFont.systemFont(ofSize: 12)
        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(selectAllButton)
        
        // 导出CSV按钮
        let exportCSVButton = NSButton(title: "导出CSV", target: self, action: #selector(exportCSV))
        exportCSVButton.bezelStyle = NSButton.BezelStyle.rounded
        exportCSVButton.font = NSFont.systemFont(ofSize: 12)
        exportCSVButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(exportCSVButton)
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = NSButton.BezelStyle.rounded
        cancelButton.font = NSFont.systemFont(ofSize: 12)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        // 确定按钮
        let okButton = NSButton(title: "确定", target: self, action: #selector(ok))
        okButton.bezelStyle = NSButton.BezelStyle.rounded
        okButton.font = NSFont.systemFont(ofSize: 12)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(okButton)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 搜索框
            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            searchField.heightAnchor.constraint(equalToConstant: 24),
            
            // 提示标签
            infoLabel.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 标签页
            tabView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.heightAnchor.constraint(equalToConstant: 240),
            
            // 按钮容器
            buttonContainer.topAnchor.constraint(equalTo: tabView.bottomAnchor, constant: 16),
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // 按钮
            selectAllButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            selectAllButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            selectAllButton.widthAnchor.constraint(equalToConstant: 80),
            
            exportCSVButton.leadingAnchor.constraint(equalTo: selectAllButton.trailingAnchor, constant: 10),
            exportCSVButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            exportCSVButton.widthAnchor.constraint(equalToConstant: 80),
            
            cancelButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -80),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            okButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            okButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    // 创建失败用例标签页视图
    private func createFailureCaseTabView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // 滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图
        failureCaseTableView = NSTableView()
        failureCaseTableView.delegate = self
        failureCaseTableView.dataSource = self
        failureCaseTableView.allowsEmptySelection = false
        
        // 添加复选框列
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkColumn"))
        checkColumn.title = ""
        checkColumn.width = 40
        failureCaseTableView.addTableColumn(checkColumn)
        
        // 添加出现次数列
        let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("countColumn"))
        countColumn.title = "次数"
        countColumn.width = 60
        failureCaseTableView.addTableColumn(countColumn)
        
        // 添加失败用例列
        let caseColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("failureCase"))
        caseColumn.title = "失败用例"
        caseColumn.width = 860
        failureCaseTableView.addTableColumn(caseColumn)
        
        scrollView.documentView = failureCaseTableView
        
        // 布局约束
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return view
    }
    
    // 创建SN标签页视图
    private func createSNTabView() -> NSView {
        #if DEBUG
        print("🔧 创建SN标签页视图")
        #endif
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // 滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图
        snTableView = NSTableView()
        snTableView.delegate = self
        snTableView.dataSource = self
        snTableView.allowsEmptySelection = false
        #if DEBUG
        print("🔧 SN表格视图已创建，列数: \(snTableView.tableColumns.count)")
        #endif
        
        // 添加复选框列（第一列）
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snCheckColumn"))
        checkColumn.title = ""
        checkColumn.width = 40
        snTableView.addTableColumn(checkColumn)
        
        // 添加失败用例数量列（第二列）
        let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snCountColumn"))
        countColumn.title = "失败次数"
        countColumn.width = 80
        snTableView.addTableColumn(countColumn)
        
        // 添加SN列（第三列）
        let snColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snColumn"))
        snColumn.title = "SN"
        snColumn.width = 840
        snTableView.addTableColumn(snColumn)
        
        #if DEBUG
        print("🔧 SN表格列已添加，列数: \(snTableView.tableColumns.count)")
        #endif
        
        scrollView.documentView = snTableView
        
        // 布局约束 - 和失败用例标签页一样
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        #if DEBUG
        print("🔧 SN标签页视图创建完成")
        #endif
        return view
    }
    
    // 创建通道号标签页视图
    private func createChannelTabView() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // 滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图
        channelTableView = NSTableView()
        channelTableView.delegate = self
        channelTableView.dataSource = self
        channelTableView.allowsEmptySelection = false
        
        // 添加复选框列（第一列）
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channelCheckColumn"))
        checkColumn.title = ""
        checkColumn.width = 40
        channelTableView.addTableColumn(checkColumn)
        
        // 添加失败用例数量列（第二列）
        let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channelCountColumn"))
        countColumn.title = "失败次数"
        countColumn.width = 80
        channelTableView.addTableColumn(countColumn)
        
        // 添加通道号列（第三列）
        let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channelColumn"))
        channelColumn.title = "通道号"
        channelColumn.width = 840
        channelTableView.addTableColumn(channelColumn)
        
        scrollView.documentView = channelTableView
        
        // 布局约束 - 和失败用例标签页一样
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return view
    }
    
    @objc private func selectAllFailures() {
        // 切换全选/取消全选状态
        let allSelected = failureCases.allSatisfy { blockedFailures.contains($0) }
        
        if allSelected {
            // 取消全选
            blockedFailures.removeAll()
        } else {
            // 全选
            blockedFailures = Set(failureCases)
        }
        
        // 刷新所有表格
        failureCaseTableView.reloadData()
        snTableView.reloadData()
        channelTableView.reloadData()
    }
    
    @objc private func searchFailureCase(_ sender: NSSearchField) {
        let searchText = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return }
        
        // 在失败用例列表中搜索
        for (index, failureCase) in failureCases.enumerated() {
            if failureCase.localizedCaseInsensitiveContains(searchText) {
                // 找到匹配项，选中并滚动到该位置
                failureCaseTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                failureCaseTableView.scrollRowToVisible(index)
                #if DEBUG
                print("🔍 定位到失败用例: \(failureCase) (行 \(index))")
                #endif
                return
            }
        }
        
        // 未找到匹配项
        #if DEBUG
        print("❌ 未找到匹配的失败用例: \(searchText)")
        #endif
    }
    
    @objc private func cancel() {
        #if DEBUG
        print("🔄 CurrentFailFilterController: cancel() 被调用")
        #endif
        // 关闭弹出式面板
        popover?.close()
    }
    
    @objc private func ok() {
        #if DEBUG
        print("🔄 CurrentFailFilterController: ok() 被调用")
        #endif
        
        // 调用回调
        completionHandler?(blockedFailures)
        
        // 关闭弹出式面板
        popover?.close()
    }
    
    @objc private func exportCSV() {
        #if DEBUG
        print("🔄 CurrentFailFilterController: exportCSV() 被调用")
        #endif
        
        // 收集所有通道号
        var channels = Set<String>()
        for (channel, _) in channelToFailures {
            channels.insert(channel)
        }
        // 按通道号排序
        let sortedChannels = channels.sorted()
        
        // 收集所有失败用例（已经按失败次数降序排列）
        let sortedFailures = failureCases
        
        // 生成CSV内容
        var csvContent = "失败用例,总次数"
        for channel in sortedChannels {
            csvContent += ",通道 \(channel)"
        }
        csvContent += "\n"
        
        // 为每个失败用例生成一行
        for failureCase in sortedFailures {
            let totalCount = failureCaseCounts[failureCase] ?? 0
            var row = "\"\(failureCase)\",\(totalCount)"
            
            // 统计每个通道的失败次数
            for channel in sortedChannels {
                let channelFailures = channelToFailures[channel] ?? []
                let count = channelFailures.filter { $0 == failureCase }.count
                row += ",\(count)"
            }
            
            csvContent += row + "\n"
        }
        
        // 保存到文件
        let savePanel = NSSavePanel()
        savePanel.title = "导出CSV文件"
        savePanel.nameFieldStringValue = "failures_by_channel.csv"
        savePanel.allowedFileTypes = ["csv"]
        
        savePanel.begin { (result) in
            if result == .OK, let url = savePanel.url {
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    #if DEBUG
                    print("✅ 导出CSV成功: \(url.path)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ 导出CSV失败: \(error)")
                    #endif
                }
            }
        }
    }
    
    deinit {
        #if DEBUG
        print("CurrentFailFilterController 被释放")
        #endif
    }
    
    // MARK: - NSTabViewDelegate
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        #if DEBUG
        print("🔄 切换到标签页: \(tabViewItem?.label ?? "未知")")
        #endif
        
        // 刷新当前标签页的表格数据
        if let identifier = tabViewItem?.identifier as? String {
            switch identifier {
            case "失败用例":
                #if DEBUG
                print("🔧 刷新失败用例表格，行数=\(failureCases.count)")
                print("🔧 失败用例表格 frame=\(failureCaseTableView.frame), bounds=\(failureCaseTableView.bounds)")
                if let scrollView = failureCaseTableView.superview as? NSClipView {
                    print("🔧 失败用例 scrollView frame=\(scrollView.frame), bounds=\(scrollView.bounds)")
                }
                if let tabViewItem = tabViewItem, let view = tabViewItem.view {
                    print("🔧 失败用例标签页视图 frame=\(view.frame), bounds=\(view.bounds)")
                }
                #endif
                failureCaseTableView.reloadData()
                failureCaseTableView.layout()
                failureCaseTableView.setNeedsDisplay()
            case "SN":
                #if DEBUG
                print("🔧 刷新SN表格，行数=\(snToFailures.keys.count), SNs=\(snToFailures.keys)")
                print("🔧 SN表格 frame=\(snTableView.frame), bounds=\(snTableView.bounds), superview=\(String(describing: snTableView.superview))")
                if let scrollView = snTableView.superview as? NSClipView {
                    print("🔧 scrollView frame=\(scrollView.frame), bounds=\(scrollView.bounds)")
                    if let documentView = scrollView.documentView {
                        print("🔧 documentView frame=\(documentView.frame), bounds=\(documentView.bounds)")
                    }
                }
                if let tabViewItem = tabViewItem, let view = tabViewItem.view {
                    print("🔧 标签页视图 frame=\(view.frame), bounds=\(view.bounds)")
                    // 强制更新标签页视图的布局
                    view.needsLayout = true
                    view.layoutSubtreeIfNeeded()
                    print("🔧 更新布局后，标签页视图 frame=\(view.frame), bounds=\(view.bounds)")
                }
                #endif
                // 在主线程异步执行reloadData，确保表格视图已经完全布局好
                DispatchQueue.main.async {
                    self.snTableView.reloadData()
                    self.snTableView.layout()
                    self.snTableView.needsDisplay = true
                }
            case "通道号":
                #if DEBUG
                print("🔧 刷新通道号表格，行数=\(channelToFailures.keys.count)")
                print("🔧 通道号表格 frame=\(channelTableView.frame), bounds=\(channelTableView.bounds), superview=\(String(describing: channelTableView.superview))")
                #endif
                channelTableView.reloadData()
                channelTableView.layout()
                channelTableView.setNeedsDisplay()
            default:
                break
            }
        }
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource
extension CurrentFailFilterController: NSTableViewDelegate, NSTableViewDataSource {
    
    // 获取按失败次数排序的SN列表
    private func getSortedSNs() -> [String] {
        let sorted = snToFailures.keys.sorted { sn1, sn2 in
            let count1 = snToFailures[sn1]?.count ?? 0
            let count2 = snToFailures[sn2]?.count ?? 0
            return count1 > count2
        }
        #if DEBUG
        print("🔧 getSortedSNs: SN数量=\(sorted.count), 前5个=\(sorted.prefix(5))")
        #endif
        return sorted
    }
    
    // 获取按失败次数排序的通道号列表
    private func getSortedChannels() -> [String] {
        return channelToFailures.keys.sorted { ch1, ch2 in
            let count1 = channelToFailures[ch1]?.count ?? 0
            let count2 = channelToFailures[ch2]?.count ?? 0
            return count1 > count2
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == failureCaseTableView {
            let count = failureCases.count
            #if DEBUG
            print("🔧 numberOfRows: failureCaseTableView 行数=\(count)")
            #endif
            return count
        } else if tableView == snTableView {
            let count = snToFailures.keys.count
            #if DEBUG
            print("🔧 numberOfRows: snTableView 行数=\(count), snToFailures.keys=\(snToFailures.keys)")
            #endif
            return count
        } else if tableView == channelTableView {
            let count = channelToFailures.keys.count
            #if DEBUG
            print("🔧 numberOfRows: channelTableView 行数=\(count)")
            #endif
            return count
        }
        #if DEBUG
        print("🔧 numberOfRows: 未知表格")
        #endif
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
        #if DEBUG
        print("🔧 tableView:viewFor:row: 被调用，表格=\(tableView === failureCaseTableView ? "failureCaseTableView" : (tableView === snTableView ? "snTableView" : "channelTableView")), 行=\(row), 列=\(tableColumn.identifier.rawValue)")
        #endif
        
        // 失败用例表格
        if tableView == failureCaseTableView {
            if tableColumn.identifier == NSUserInterfaceItemIdentifier("checkColumn") {
                // 复选框列
                let cellIdentifier = NSUserInterfaceItemIdentifier("CheckCell")
                
                var cell: NSTableCellView
                
                if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                    cell = reusedCell
                } else {
                    // 创建新单元格
                    cell = NSTableCellView()
                    cell.identifier = cellIdentifier
                    
                    // 创建复选框
                    let checkBox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkBoxToggled(_:)))
                    checkBox.font = NSFont.systemFont(ofSize: 12)
                    checkBox.translatesAutoresizingMaskIntoConstraints = false
                    checkBox.setAccessibilityIdentifier("CheckBox_\(row)")
                    
                    cell.addSubview(checkBox)
                    
                    // 布局约束
                    NSLayoutConstraint.activate([
                        checkBox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                        checkBox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10)
                    ])
                }
                
                // 设置复选框状态
                if let checkBox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                    checkBox.state = blockedFailures.contains(failureCases[row]) ? .on : .off
                    checkBox.tag = row
                }
                
                return cell
            } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("countColumn") {
                // 出现次数列
                let cellIdentifier = NSUserInterfaceItemIdentifier("CountCell")
                
                var cell: NSTableCellView
                
                if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                    cell = reusedCell
                } else {
                    // 创建新单元格
                    cell = NSTableCellView()
                    cell.identifier = cellIdentifier
                    
                    // 创建文本字段
                    let textField = NSTextField()
                    textField.isEditable = false
                    textField.isSelectable = false
                    textField.font = NSFont.systemFont(ofSize: 12)
                    textField.alignment = .center
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    
                    cell.addSubview(textField)
                    cell.textField = textField
                    
                    // 布局约束
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                        textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                    ])
                }
                
                // 设置文本内容 - 显示出现次数
                let failureCase = failureCases[row]
                let count = failureCaseCounts[failureCase] ?? 0
                cell.textField?.stringValue = "\(count)"
                
                return cell
            } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("failureCase") {
                // 失败用例列
                let cellIdentifier = NSUserInterfaceItemIdentifier("CaseCell")
                
                var cell: NSTableCellView
                
                if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                    cell = reusedCell
                } else {
                    // 创建新单元格
                    cell = NSTableCellView()
                    cell.identifier = cellIdentifier
                    
                    // 创建文本字段
                    let textField = NSTextField()
                    textField.isEditable = false
                    textField.isSelectable = true
                    textField.font = NSFont.systemFont(ofSize: 12)
                    textField.translatesAutoresizingMaskIntoConstraints = false
                    
                    cell.addSubview(textField)
                    cell.textField = textField
                    
                    // 布局约束
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                        textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                        textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                    ])
                }
                
                // 设置文本内容
                cell.textField?.stringValue = failureCases[row]
                
                return cell
            }
        } else if tableView == snTableView {
            // SN表格 - 使用按失败次数排序的数据
            #if DEBUG
            print("🔧 tableView:viewFor:row: SN表格，行=\(row), 列=\(tableColumn.identifier.rawValue)")
            #endif
            let sortedSNs = getSortedSNs()
            if row < sortedSNs.count {
                let sn = sortedSNs[row]
                #if DEBUG
                print("🔧 SN表格：处理SN=\(sn), 失败次数=\(snToFailures[sn]?.count ?? 0)")
                #endif
                
                if tableColumn.identifier == NSUserInterfaceItemIdentifier("snCheckColumn") {
                    // 复选框列（第一列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("SNCheckCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建复选框
                        let checkBox = NSButton(checkboxWithTitle: "", target: self, action: #selector(snCheckBoxToggled(_:)))
                        checkBox.font = NSFont.systemFont(ofSize: 12)
                        checkBox.translatesAutoresizingMaskIntoConstraints = false
                        checkBox.setAccessibilityIdentifier("SNCheckBox_\(row)")
                        
                        cell.addSubview(checkBox)
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            checkBox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                            checkBox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10)
                        ])
                    }
                    
                    // 设置复选框状态
                    if let checkBox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                        // 检查该SN的所有失败用例是否都被屏蔽
                        let snFailures = snToFailures[sn] ?? []
                        let allBlocked = snFailures.allSatisfy { blockedFailures.contains($0) }
                        checkBox.state = allBlocked ? .on : .off
                        checkBox.tag = row
                    }
                    
                    return cell
                } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("snCountColumn") {
                    // 失败用例数量列（第二列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("SNCountCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建文本字段
                        let textField = NSTextField()
                        textField.isEditable = false
                        textField.isSelectable = false
                        textField.font = NSFont.systemFont(ofSize: 12)
                        textField.alignment = .center
                        textField.translatesAutoresizingMaskIntoConstraints = false
                        
                        cell.addSubview(textField)
                        cell.textField = textField
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                        ])
                    }
                    
                    // 设置文本内容 - 显示失败次数
                    let snFailures = snToFailures[sn] ?? []
                    cell.textField?.stringValue = "\(snFailures.count)"
                    
                    return cell
                } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("snColumn") {
                    // SN列（第三列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("SNCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建文本字段
                        let textField = NSTextField()
                        textField.isEditable = false
                        textField.isSelectable = true
                        textField.font = NSFont.systemFont(ofSize: 12)
                        textField.translatesAutoresizingMaskIntoConstraints = false
                        
                        cell.addSubview(textField)
                        cell.textField = textField
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                        ])
                    }
                    
                    // 设置文本内容
                    cell.textField?.stringValue = sn
                    
                    return cell
                }
            }
        } else if tableView == channelTableView {
            // 通道号表格 - 使用按失败次数排序的数据
            let sortedChannels = getSortedChannels()
            if row < sortedChannels.count {
                let channel = sortedChannels[row]
                
                if tableColumn.identifier == NSUserInterfaceItemIdentifier("channelCheckColumn") {
                    // 复选框列（第一列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("ChannelCheckCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建复选框
                        let checkBox = NSButton(checkboxWithTitle: "", target: self, action: #selector(channelCheckBoxToggled(_:)))
                        checkBox.font = NSFont.systemFont(ofSize: 12)
                        checkBox.translatesAutoresizingMaskIntoConstraints = false
                        checkBox.setAccessibilityIdentifier("ChannelCheckBox_\(row)")
                        
                        cell.addSubview(checkBox)
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            checkBox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                            checkBox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10)
                        ])
                    }
                    
                    // 设置复选框状态
                    if let checkBox = cell.subviews.first(where: { $0 is NSButton }) as? NSButton {
                        // 检查该通道的所有失败用例是否都被屏蔽
                        let channelFailures = channelToFailures[channel] ?? []
                        let allBlocked = channelFailures.allSatisfy { blockedFailures.contains($0) }
                        checkBox.state = allBlocked ? .on : .off
                        checkBox.tag = row
                    }
                    
                    return cell
                } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("channelCountColumn") {
                    // 失败用例数量列（第二列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("ChannelCountCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建文本字段
                        let textField = NSTextField()
                        textField.isEditable = false
                        textField.isSelectable = false
                        textField.font = NSFont.systemFont(ofSize: 12)
                        textField.alignment = .center
                        textField.translatesAutoresizingMaskIntoConstraints = false
                        
                        cell.addSubview(textField)
                        cell.textField = textField
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                        ])
                    }
                    
                    // 设置文本内容 - 显示失败次数
                    let channelFailures = channelToFailures[channel] ?? []
                    cell.textField?.stringValue = "\(channelFailures.count)"
                    
                    return cell
                } else if tableColumn.identifier == NSUserInterfaceItemIdentifier("channelColumn") {
                    // 通道号列（第三列）
                    let cellIdentifier = NSUserInterfaceItemIdentifier("ChannelCell")
                    
                    var cell: NSTableCellView
                    
                    if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                        cell = reusedCell
                    } else {
                        // 创建新单元格
                        cell = NSTableCellView()
                        cell.identifier = cellIdentifier
                        
                        // 创建文本字段
                        let textField = NSTextField()
                        textField.isEditable = false
                        textField.isSelectable = true
                        textField.font = NSFont.systemFont(ofSize: 12)
                        textField.translatesAutoresizingMaskIntoConstraints = false
                        
                        cell.addSubview(textField)
                        cell.textField = textField
                        
                        // 布局约束
                        NSLayoutConstraint.activate([
                            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
                        ])
                    }
                    
                    // 设置文本内容
                    cell.textField?.stringValue = channel
                    
                    return cell
                }
            }
        }
        
        return nil
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
    
    @objc private func checkBoxToggled(_ sender: NSButton) {
        let row = sender.tag
        if row < failureCases.count {
            let failureCase = failureCases[row]
            if sender.state == .on {
                blockedFailures.insert(failureCase)
            } else {
                blockedFailures.remove(failureCase)
            }
        }
    }
    
    @objc private func snCheckBoxToggled(_ sender: NSButton) {
        let row = sender.tag
        let sortedSNs = getSortedSNs()
        if row < sortedSNs.count {
            let sn = sortedSNs[row]
            let snFailures = snToFailures[sn] ?? []
            if sender.state == .on {
                // 屏蔽该SN的所有失败用例
                for failureCase in snFailures {
                    blockedFailures.insert(failureCase)
                }
            } else {
                // 取消屏蔽该SN的所有失败用例
                for failureCase in snFailures {
                    blockedFailures.remove(failureCase)
                }
            }
            // 刷新所有表格
            failureCaseTableView.reloadData()
            snTableView.reloadData()
            channelTableView.reloadData()
        }
    }
    
    @objc private func channelCheckBoxToggled(_ sender: NSButton) {
        let row = sender.tag
        let sortedChannels = getSortedChannels()
        if row < sortedChannels.count {
            let channel = sortedChannels[row]
            let channelFailures = channelToFailures[channel] ?? []
            if sender.state == .on {
                // 屏蔽该通道的所有失败用例
                for failureCase in channelFailures {
                    blockedFailures.insert(failureCase)
                }
            } else {
                // 取消屏蔽该通道的所有失败用例
                for failureCase in channelFailures {
                    blockedFailures.remove(failureCase)
                }
            }
            // 刷新所有表格
            failureCaseTableView.reloadData()
            snTableView.reloadData()
            channelTableView.reloadData()
        }
    }
}
