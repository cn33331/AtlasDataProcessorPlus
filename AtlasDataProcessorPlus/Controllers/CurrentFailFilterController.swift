// CurrentFailFilterController.swift
// 用于当前失败用例筛选的弹出式面板控制器

import Cocoa

class CurrentFailFilterController: NSViewController {
    
    // 表格视图
    private var tableView: NSTableView!
    
    // 失败用例列表
    var failureCases: [String] = []
    
    // 失败用例出现次数统计
    var failureCaseCounts: [String: Int] = [:]
    
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
        // 创建主视图 - 增加宽度到1000以适应长文本
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 300))
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
        
        // 提示标签
        let infoLabel = NSTextField(labelWithString: "勾选要屏蔽的失败用例")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // 滚动视图 - 宽度设置为960（主视图1000 - 左右边距40）
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 960, height: 180))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图 - 宽度与滚动视图一致
        tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 960, height: 180))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        
        // 添加复选框列
        let checkColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkColumn"))
        checkColumn.title = ""
        checkColumn.width = 40
        tableView.addTableColumn(checkColumn)
        
        // 添加出现次数列（作为第一列）
        let countColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("countColumn"))
        countColumn.title = "次数"
        countColumn.width = 60
        tableView.addTableColumn(countColumn)
        
        // 添加失败用例列 - 宽度设置为860（960 - 40 - 60）
        let caseColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("failureCase"))
        caseColumn.title = "失败用例"
        caseColumn.width = 860
        tableView.addTableColumn(caseColumn)
        
        scrollView.documentView = tableView
        
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
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.font = NSFont.systemFont(ofSize: 12)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        // 确定按钮
        let okButton = NSButton(title: "确定", target: self, action: #selector(ok))
        okButton.bezelStyle = .rounded
        okButton.font = NSFont.systemFont(ofSize: 12)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(okButton)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 提示标签
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 滚动视图
            scrollView.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 180),
            
            // 按钮容器
            buttonContainer.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // 按钮
            selectAllButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            selectAllButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            selectAllButton.widthAnchor.constraint(equalToConstant: 80),
            
            cancelButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -80),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            okButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            okButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 80)
        ])
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
        
        // 刷新表格
        tableView.reloadData()
    }
    
    @objc private func cancel() {
        print("🔄 CurrentFailFilterController: cancel() 被调用")
        // 关闭弹出式面板
        popover?.close()
    }
    
    @objc private func ok() {
        print("🔄 CurrentFailFilterController: ok() 被调用")
        
        // 调用回调
        completionHandler?(blockedFailures)
        
        // 关闭弹出式面板
        popover?.close()
    }
    
    deinit {
        print("CurrentFailFilterController 被释放")
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource
extension CurrentFailFilterController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return failureCases.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        
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
}
