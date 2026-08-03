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
    
    // SN到失败用例的映射
    var snToFailures: [String: [Any]] = [:]
    
    // 各标签页独立的屏蔽集合
    var failureCaseBlocked: Set<String> = []
    var snBlocked: Set<String> = []
    
    // 回调闭包 - 传递被屏蔽的失败用例和SN
    var completionHandler: ((Set<String>, Set<String>) -> Void)?
    
    // 弹出式面板
    private weak var popover: NSPopover?
    
    // 设置弹出式面板引用
    func setPopover(_ popover: NSPopover) {
        self.popover = popover
    }
    
    override func loadView() {
        // 创建主视图 - 增加宽度到1000以适应长文本，高度增加到480以容纳标签页
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 480))
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
        
        // 分段控件 - 只有失败用例和SN
        segmentedControl = NSSegmentedControl(labels: ["失败用例", "SN"], trackingMode: .selectOne, target: self, action: #selector(segmentedControlChanged(_:)))
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
            contentContainer.heightAnchor.constraint(equalToConstant: 320),
            
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
        
        for subview in contentContainer.subviews {
            subview.removeFromSuperview()
        }
        
        switch selectedSegment {
        case 0:
            showFailureCaseFilter(in: contentContainer)
        case 1:
            showSNFilter(in: contentContainer)
        default:
            break
        }
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
        if let segmentedControl = segmentedControl {
            let selectedSegment = segmentedControl.selectedSegment
            
            switch selectedSegment {
            case 0: // 失败用例
                let allSelected = failureCases.allSatisfy { failureCaseBlocked.contains($0) }
                if allSelected {
                    failureCaseBlocked.removeAll()
                } else {
                    failureCaseBlocked = Set(failureCases)
                }
                failureCaseTableView?.reloadData()
            case 1: // SN
                let allSelected = snToFailures.keys.allSatisfy { snBlocked.contains($0) }
                if allSelected {
                    snBlocked.removeAll()
                } else {
                    snBlocked = Set(snToFailures.keys)
                }
                snTableView?.reloadData()
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
        completionHandler?(failureCaseBlocked, snBlocked)
        popover?.close()
    }
    
    @objc private func exportCSV() {
        let savePanel = NSSavePanel()
        savePanel.title = "导出CSV文件"
        savePanel.nameFieldStringValue = "failures.csv"
        savePanel.allowedFileTypes = ["csv"]
        
        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                var csvContent = "失败用例,出现次数\n"
                for failureCase in self.failureCases {
                    let count = self.failureCaseCounts[failureCase] ?? 0
                    csvContent += "\"\(failureCase)\",\(count)\n"
                }
                do {
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                } catch {}
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
    
    private func getSortedSNs() -> [String] {
        let sorted = snToFailures.keys.sorted { sn1, sn2 in
            let count1 = snToFailures[sn1]?.count ?? 0
            let count2 = snToFailures[sn2]?.count ?? 0
            return count1 > count2
        }
        return sorted
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == failureCaseTableView {
            return failureCases.count
        } else if tableView == snTableView {
            return snToFailures.keys.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
        if tableView == failureCaseTableView {
            return failureCaseCell(for: tableColumn, row: row)
        } else if tableView == snTableView {
            return snCell(for: tableColumn, row: row)
        }
        return nil
    }
    
    private func failureCaseCell(for column: NSTableColumn, row: Int) -> NSView? {
        if column.identifier == NSUserInterfaceItemIdentifier("checkColumn") {
            let cell = makeCheckCell(tableView: failureCaseTableView, identifier: "CheckCell", row: row,
                                     isChecked: failureCaseBlocked.contains(failureCases[row]),
                                     action: #selector(checkBoxToggled(_:)))
            return cell
        } else if column.identifier == NSUserInterfaceItemIdentifier("countColumn") {
            let cell = makeTextCell(tableView: failureCaseTableView, identifier: "CountCell",
                                    text: "\(failureCaseCounts[failureCases[row]] ?? 0)", alignment: .center)
            return cell
        } else if column.identifier == NSUserInterfaceItemIdentifier("failureCase") {
            let cell = makeTextCell(tableView: failureCaseTableView, identifier: "CaseCell",
                                    text: failureCases[row], alignment: .left, selectable: true)
            return cell
        }
        return nil
    }
    
    private func snCell(for column: NSTableColumn, row: Int) -> NSView? {
        let sortedSNs = getSortedSNs()
        guard row < sortedSNs.count else { return nil }
        let sn = sortedSNs[row]
        
        if column.identifier == NSUserInterfaceItemIdentifier("snCheckColumn") {
            let cell = makeCheckCell(tableView: snTableView, identifier: "SNCheckCell", row: row,
                                     isChecked: snBlocked.contains(sn),
                                     action: #selector(snCheckBoxToggled(_:)))
            return cell
        } else if column.identifier == NSUserInterfaceItemIdentifier("snCountColumn") {
            let count = (snToFailures[sn] ?? []).count
            let cell = makeTextCell(tableView: snTableView, identifier: "SNCountCell",
                                    text: "\(count)", alignment: .center)
            return cell
        } else if column.identifier == NSUserInterfaceItemIdentifier("snColumn") {
            let cell = makeTextCell(tableView: snTableView, identifier: "SNCell",
                                    text: sn, alignment: .left, selectable: true)
            return cell
        }
        return nil
    }
    
    private func makeCheckCell(tableView: NSTableView, identifier: String, row: Int,
                               isChecked: Bool, action: Selector) -> NSTableCellView {
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            if let checkBox = reused.subviews.first(where: { $0 is NSButton }) as? NSButton {
                checkBox.state = isChecked ? .on : .off
                checkBox.tag = row
                checkBox.target = self
                checkBox.action = action
            }
            return reused
        }
        
        let cell = NSTableCellView()
        cell.identifier = cellIdentifier
        let checkBox = NSButton(checkboxWithTitle: "", target: self, action: action)
        checkBox.font = NSFont.systemFont(ofSize: 12)
        checkBox.translatesAutoresizingMaskIntoConstraints = false
        checkBox.state = isChecked ? .on : .off
        checkBox.tag = row
        cell.addSubview(checkBox)
        NSLayoutConstraint.activate([
            checkBox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            checkBox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10)
        ])
        return cell
    }
    
    private func makeTextCell(tableView: NSTableView, identifier: String,
                              text: String, alignment: NSTextAlignment, selectable: Bool = false) -> NSTableCellView {
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            reused.textField?.stringValue = text
            return reused
        }
        
        let cell = NSTableCellView()
        cell.identifier = cellIdentifier
        let textField = NSTextField()
        textField.isEditable = false
        textField.isSelectable = selectable
        textField.font = NSFont.systemFont(ofSize: 12)
        textField.alignment = alignment
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        cell.textField = textField
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
        ])
        textField.stringValue = text
        return cell
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
        let sortedSNs = getSortedSNs()
        if row < sortedSNs.count {
            let sn = sortedSNs[row]
            if sender.state == .on {
                snBlocked.insert(sn)
            } else {
                snBlocked.remove(sn)
            }
            failureCaseTableView?.reloadData()
            snTableView?.reloadData()
        }
    }
}
