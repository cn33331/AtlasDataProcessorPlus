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

class CurrentFailFilterController: NSViewController {
    
    // 表格视图
    private var failureCaseTableView: NSTableView!
    private var snTableView: NSTableView!
    private var channelTableView: NSTableView!
    
    // 分段控件
    private var segmentedControl: NSSegmentedControl!
    
    // 内容容器
    private var contentContainer: NSView!
    
    // 搜索框
    private var searchField: CustomSearchField!
    
    // 失败用例列表
    var failureCases: [String] = []
    
    // 失败用例出现次数统计
    var failureCaseCounts: [String: Int] = [:]
    
    // 通道号到失败用例的映射（标题行计数）
    var channelToFailures: [String: [String]] = [:]
    
    // 通道号到失败用例内容行计数的映射
    var channelToFailureContentCounts: [String: [String: Int]] = [:]
    
    // SN到失败用例的映射
    var snToFailures: [String: [String]] = [:]
    
    // 已屏蔽的失败用例集合
    var blockedFailures: Set<String> = []
    
    // 各标签页独立的屏蔽集合
    var failureCaseBlocked: Set<String> = []  // 存储被屏蔽的失败用例
    var snBlocked: Set<String> = []  // 存储被屏蔽的SN
    var channelBlocked: Set<String> = []  // 存储被屏蔽的通道号
    
    // 回调闭包 - 传递被屏蔽的失败用例、SN和通道号
    var completionHandler: ((Set<String>, Set<String>, Set<String>) -> Void)?
    
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
        searchField.placeholderString = "搜索失败用例和SN，按回车定位"
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.target = self
        searchField.action = #selector(searchFailureCaseOrSN(_:))
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
        
        // 分段控件 - 用于切换不同的筛选方式
        segmentedControl = NSSegmentedControl(labels: ["失败用例", "SN", "通道号"], trackingMode: .selectOne, target: self, action: #selector(segmentedControlChanged(_:)))
        segmentedControl.selectedSegment = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        // 内容容器 - 用于显示不同的筛选内容
        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        
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
            
            // 分段控件
            segmentedControl.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // 内容容器
            contentContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 16),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentContainer.heightAnchor.constraint(equalToConstant: 240),
            
            // 按钮容器
            buttonContainer.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 16),
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
        
        // 初始显示失败用例筛选
        showFailureCaseFilter(in: contentContainer)
    }
    
    // 分段控件的回调方法
    @objc private func segmentedControlChanged(_ sender: NSSegmentedControl) {
        let selectedSegment = sender.selectedSegment
        
        #if DEBUG
        print("🔧 切换到标签页: \(selectedSegment == 0 ? "失败用例" : (selectedSegment == 1 ? "SN" : "通道号"))")
        print("🔧 切换前 - 失败用例屏蔽: \(failureCaseBlocked.count), SN屏蔽: \(snBlocked.count), 通道屏蔽: \(channelBlocked.count)")
        #endif
        
        // 移除内容容器中的所有子视图
        for subview in contentContainer.subviews {
            subview.removeFromSuperview()
        }
        
        // 根据选择的选项显示不同的筛选内容
        switch selectedSegment {
        case 0: // 失败用例
            showFailureCaseFilter(in: contentContainer)
        case 1: // SN
            showSNFilter(in: contentContainer)
        case 2: // 通道号
            showChannelFilter(in: contentContainer)
        default:
            break
        }
        
        #if DEBUG
        print("🔧 切换后 - 失败用例屏蔽: \(failureCaseBlocked.count), SN屏蔽: \(snBlocked.count), 通道屏蔽: \(channelBlocked.count)")
        #endif
    }
    
    // 显示失败用例筛选
    private func showFailureCaseFilter(in container: NSView) {
        let (view, tableView) = createTabView(columns: [
            (identifier: "checkColumn", title: "", width: CGFloat(40.0)),
            (identifier: "countColumn", title: "次数", width: CGFloat(60.0)),
            (identifier: "failureCase", title: "失败用例", width: CGFloat(860.0))
        ])
        failureCaseTableView = tableView
        
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 刷新表格数据
        failureCaseTableView.reloadData()
    }
    
    // 显示SN筛选
    private func showSNFilter(in container: NSView) {
        #if DEBUG
        print("🔧 显示SN筛选")
        print("🔧 SN到失败用例的映射: \(snToFailures)")
        for (sn, failures) in snToFailures {
            let uniqueFailures = Set(failures)
            print("🔧 SN=\(sn), 内容行数量=\(failures.count), 唯一失败用例数量=\(uniqueFailures.count)")
            print("🔧 唯一失败用例: \(uniqueFailures)")
        }
        #endif
        let (view, tableView) = createTabView(columns: [
            (identifier: "snCheckColumn", title: "", width: CGFloat(40.0)),
            (identifier: "snCountColumn", title: "失败次数", width: CGFloat(80.0)),
            (identifier: "snColumn", title: "SN", width: CGFloat(840.0))
        ])
        snTableView = tableView
        
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 刷新表格数据
        snTableView.reloadData()
        #if DEBUG
        print("🔧 SN表格已显示，行数=\(snToFailures.keys.count)")
        #endif
    }
    
    // 显示通道号筛选
    private func showChannelFilter(in container: NSView) {
        #if DEBUG
        print("🔧 显示通道号筛选")
        print("🔧 通道号到失败用例的映射: \(channelToFailures)")
        for (channel, failures) in channelToFailures {
            print("🔧 通道号=\(channel), 内容行数量=\(failures.count), 唯一失败用例数量=\(Set(failures).count)")
        }
        #endif
        let (view, tableView) = createTabView(columns: [
            (identifier: "channelCheckColumn", title: "", width: CGFloat(40.0)),
            (identifier: "channelCountColumn", title: "失败次数", width: CGFloat(80.0)),
            (identifier: "channelColumn", title: "通道号", width: CGFloat(840.0))
        ])
        channelTableView = tableView
        
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 刷新表格数据
        channelTableView.reloadData()
        #if DEBUG
        print("🔧 通道号表格已显示，行数=\(channelToFailures.keys.count)")
        #endif
    }
    
    // 创建标签页视图的通用方法
    private func createTabView(columns: [(identifier: String, title: String, width: CGFloat)]) -> (NSView, NSTableView) {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // 滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图
        let tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        
        // 添加列
        for column in columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.identifier))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableView.addTableColumn(tableColumn)
        }
        
        scrollView.documentView = tableView
        
        // 布局约束
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        return (view, tableView)
    }
    
    @objc private func selectAllFailures() {
        #if DEBUG
        print("🔧 selectAllFailures 被调用")
        #endif
        
        // 根据当前选中的标签页对对应的表格进行全选
        if let segmentedControl = segmentedControl {
            let selectedSegment = segmentedControl.selectedSegment
            
            switch selectedSegment {
            case 0: // 失败用例
                // 切换全选/取消全选状态
                let allSelected = failureCases.allSatisfy { failureCaseBlocked.contains($0) }
                
                if allSelected {
                    // 取消全选
                    failureCaseBlocked.removeAll()
                } else {
                    // 全选
                    failureCaseBlocked = Set(failureCases)
                }
                
                if failureCaseTableView != nil {
                    failureCaseTableView.reloadData()
                }
            case 1: // SN
                // 切换全选/取消全选状态
                let allSelected = snToFailures.keys.allSatisfy { snBlocked.contains($0) }
                
                if allSelected {
                    // 取消全选
                    snBlocked.removeAll()
                } else {
                    // 全选
                    snBlocked = Set(snToFailures.keys)
                }
                
                if snTableView != nil {
                    snTableView.reloadData()
                }
            case 2: // 通道号
                // 切换全选/取消全选状态
                let allSelected = channelToFailures.keys.allSatisfy { channelBlocked.contains($0) }
                
                if allSelected {
                    // 取消全选
                    channelBlocked.removeAll()
                } else {
                    // 全选
                    channelBlocked = Set(channelToFailures.keys)
                }
                
                if channelTableView != nil {
                    channelTableView.reloadData()
                }
            default:
                break
            }
        }
    }
    
    @objc private func searchFailureCaseOrSN(_ sender: NSSearchField) {
        let searchText = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchText.isEmpty else { return }
        
        #if DEBUG
        print("🔍 搜索失败用例或SN: \(searchText)")
        #endif
        
        // 首先在失败用例列表中搜索
        for (index, failureCase) in failureCases.enumerated() {
            if failureCase.localizedCaseInsensitiveContains(searchText) {
                // 找到匹配的失败用例，切换到失败用例标签页
                segmentedControl.selectedSegment = 0
                segmentedControlChanged(segmentedControl)
                
                // 确保表格视图已经加载
                if failureCaseTableView != nil {
                    failureCaseTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                    failureCaseTableView.scrollRowToVisible(index)
                    #if DEBUG
                    print("✅ 定位到失败用例: \(failureCase) (行 \(index))")
                    #endif
                }
                return
            }
        }
        
        // 如果在失败用例中没找到，在SN列表中搜索
        let sortedSNs = getSortedSNs()
        for (index, sn) in sortedSNs.enumerated() {
            if sn.localizedCaseInsensitiveContains(searchText) {
                // 找到匹配的SN，切换到SN标签页
                segmentedControl.selectedSegment = 1
                segmentedControlChanged(segmentedControl)
                
                // 确保表格视图已经加载
                if snTableView != nil {
                    snTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                    snTableView.scrollRowToVisible(index)
                    #if DEBUG
                    print("✅ 定位到SN: \(sn) (行 \(index))")
                    #endif
                }
                return
            }
        }
        
        // 未找到匹配项
        #if DEBUG
        print("❌ 未找到匹配的失败用例或SN: \(searchText)")
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
        
        #if DEBUG
        print("📋 会话屏蔽的失败用例: \(failureCaseBlocked)")
        print("📋 会话屏蔽的SN: \(snBlocked)")
        print("📋 会话屏蔽的通道号: \(channelBlocked)")
        #endif
        
        // 调用回调 - 传递三个独立的屏蔽集合
        completionHandler?(failureCaseBlocked, snBlocked, channelBlocked)
        
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
            
            // 统计每个通道的失败次数（使用内容行计数）
            for channel in sortedChannels {
                // 使用 channelToFailureContentCounts 获取内容行计数
                let count = channelToFailureContentCounts[channel]?[failureCase] ?? 0
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
        let sorted = channelToFailures.keys.sorted { ch1, ch2 in
            let count1 = channelToFailures[ch1]?.count ?? 0
            let count2 = channelToFailures[ch2]?.count ?? 0
            return count1 > count2
        }
        #if DEBUG
        print("🔧 getSortedChannels: 通道数量=\(sorted.count), 前5个=\(sorted.prefix(5))")
        #endif
        return sorted
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
                    checkBox.state = failureCaseBlocked.contains(failureCases[row]) ? .on : .off
                    checkBox.tag = row
                    // 确保复选框的action正确设置
                    checkBox.target = self
                    checkBox.action = #selector(checkBoxToggled(_:))
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
                    // 检查该SN是否被屏蔽
                    checkBox.state = snBlocked.contains(sn) ? .on : .off
                    checkBox.tag = row
                    // 确保复选框的action正确设置
                    checkBox.target = self
                    checkBox.action = #selector(snCheckBoxToggled(_:))
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
                    
                    // 设置文本内容 - 显示失败次数（使用标题行的数量）
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
                    // 检查该通道号是否被屏蔽
                    checkBox.state = channelBlocked.contains(channel) ? .on : .off
                    checkBox.tag = row
                    // 确保复选框的action正确设置
                    checkBox.target = self
                    checkBox.action = #selector(channelCheckBoxToggled(_:))
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
                    
                    // 设置文本内容 - 显示失败次数（使用标题行的数量）
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
                failureCaseBlocked.insert(failureCase)
            } else {
                failureCaseBlocked.remove(failureCase)
            }
        }
    }
    
    @objc private func snCheckBoxToggled(_ sender: NSButton) {
        let row = sender.tag
        #if DEBUG
        print("🔧 snCheckBoxToggled: 行=\(row), state=\(sender.state)")
        #endif
        let sortedSNs = getSortedSNs()
        if row < sortedSNs.count {
            let sn = sortedSNs[row]
            #if DEBUG
            print("🔧 snCheckBoxToggled: SN=\(sn)")
            #endif
            if sender.state == .on {
                // 屏蔽该SN
                snBlocked.insert(sn)
                #if DEBUG
                print("🔧 屏蔽SN: \(sn)")
                #endif
            } else {
                // 取消屏蔽该SN
                snBlocked.remove(sn)
                #if DEBUG
                print("🔧 取消屏蔽SN: \(sn)")
                #endif
            }
            #if DEBUG
            print("🔧 snCheckBoxToggled: 当前屏蔽SN数量=\(snBlocked.count)")
            #endif
            // 刷新所有表格
            if failureCaseTableView != nil {
                failureCaseTableView.reloadData()
            }
            if snTableView != nil {
                snTableView.reloadData()
            }
            if channelTableView != nil {
                channelTableView.reloadData()
            }
        }
    }
    
    @objc private func channelCheckBoxToggled(_ sender: NSButton) {
        let row = sender.tag
        #if DEBUG
        print("🔧 channelCheckBoxToggled: 行=\(row), state=\(sender.state)")
        #endif
        let sortedChannels = getSortedChannels()
        if row < sortedChannels.count {
            let channel = sortedChannels[row]
            #if DEBUG
            print("🔧 channelCheckBoxToggled: 通道=\(channel)")
            #endif
            if sender.state == .on {
                // 屏蔽该通道号
                channelBlocked.insert(channel)
                #if DEBUG
                print("🔧 屏蔽通道: \(channel)")
                #endif
            } else {
                // 取消屏蔽该通道号
                channelBlocked.remove(channel)
                #if DEBUG
                print("🔧 取消屏蔽通道: \(channel)")
                #endif
            }
            #if DEBUG
            print("🔧 channelCheckBoxToggled: 当前屏蔽通道数量=\(channelBlocked.count)")
            #endif
            // 刷新所有表格
            if failureCaseTableView != nil {
                failureCaseTableView.reloadData()
            }
            if snTableView != nil {
                snTableView.reloadData()
            }
            if channelTableView != nil {
                channelTableView.reloadData()
            }
        }
    }
}
