// BlockFailPopoverController.swift
// 用于屏蔽失败用例的弹出式面板控制器

import Cocoa

class BlockFailPopoverController: NSViewController {
    
    // 列表视图
    private var tableView: NSTableView!
    
    // 屏蔽的失败用例列表
    var blockedFailures: [String] = []
    
    // 回调闭包 - 参数为 nil 表示用户取消操作
    var completionHandler: (([String]?) -> Void)?
    
    // 确定按钮
    private var okButton: NSButton!
    
    // 取消按钮
    private var cancelButton: NSButton!
    
    // 添加按钮
    private var addButton: NSButton!
    
    // 弹出式面板
    private weak var popover: NSPopover?
    
    // 设置弹出式面板引用
    func setPopover(_ popover: NSPopover) {
        self.popover = popover
    }
    
    override func loadView() {
        // 创建主视图
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view
        
        // 创建布局
        setupUI()
    }
    
    private func setupUI() {
        // 标题
        let titleLabel = NSTextField(labelWithString: "屏蔽失败用例")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // 提示标签
        let infoLabel = NSTextField(labelWithString: "请管理要屏蔽的失败用例列表")
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        
        // 滚动视图
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 460, height: 180))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // 表格视图
        tableView = NSTableView(frame: NSRect(x: 0, y: 0, width: 460, height: 180))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        
        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("failureCase"))
        column.title = "失败用例"
        column.width = 460
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        
        // 按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // 添加按钮
        addButton = NSButton(title: "添加", target: self, action: #selector(addItem))
        addButton.bezelStyle = .rounded
        addButton.font = NSFont.systemFont(ofSize: 12)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(addButton)
        
        // 取消按钮
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.font = NSFont.systemFont(ofSize: 12)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        // 确定按钮
        okButton = NSButton(title: "确定", target: self, action: #selector(ok))
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
            addButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            addButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 80),
            
            cancelButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -80),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            okButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            okButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    @objc private func addItem() {
        // 添加一个空行
        blockedFailures.append("")
        tableView.reloadData()
        
        // 选中并编辑新添加的行
        if !blockedFailures.isEmpty {
            let lastRow = blockedFailures.count - 1
            tableView.selectRowIndexes(IndexSet(integer: lastRow), byExtendingSelection: false)
            tableView.editColumn(0, row: lastRow, with: nil, select: true)
        }
    }
    
    @objc private func cancel() {
        print("🔄 BlockFailPopoverController: cancel() 被调用")
        // 调用回调，通知取消操作
        completionHandler?(nil)
        // 关闭弹出式面板
        popover?.close()
    }
    
    @objc private func ok() {
        print("🔄 BlockFailPopoverController: ok() 被调用")
        // 过滤空项
        let filteredFailures = blockedFailures.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 调用回调
        print("📞 调用 completionHandler，过滤后的失败用例: \(filteredFailures)")
        completionHandler?(filteredFailures)
        
        // 关闭弹出式面板
        popover?.close()
    }
    
    deinit {
        // 确保所有观察者都被移除
        NotificationCenter.default.removeObserver(self)
        print("BlockFailPopoverController 被释放")
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource
extension BlockFailPopoverController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return blockedFailures.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("BlockFailCell")
        
        var cell: NSTableCellView
        
        if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = reusedCell
        } else {
            // 创建新单元格
            cell = NSTableCellView()
            cell.identifier = cellIdentifier
            
            // 创建文本字段
            let textField = NSTextField()
            textField.isEditable = true
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
        cell.textField?.stringValue = blockedFailures[row]
        
        // 添加文本更改通知
        if let textField = cell.textField {
            // 移除之前的观察者（如果有）
            NotificationCenter.default.removeObserver(self, name: NSTextField.textDidChangeNotification, object: textField)
            // 添加新的观察者
            NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: NSTextField.textDidChangeNotification, object: textField)
            textField.tag = row
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
    
    @objc private func textDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            let row = textField.tag
            if row < blockedFailures.count {
                blockedFailures[row] = textField.stringValue
            }
        }
    }
    
    // 支持删除行
    func tableView(_ tableView: NSTableView, canRemoveRow row: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, removeRow row: Int) {
        if row < blockedFailures.count {
            blockedFailures.remove(at: row)
            tableView.reloadData()
        }
    }
}
