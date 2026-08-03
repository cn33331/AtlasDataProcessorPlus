// DetailModalController.swift
// 测试详情弹窗 — 基本信息 + 全部项目 + 仅Fail 三个标签页

import Cocoa

class DetailModalController: NSViewController {
    
    private let record: TestRecord
    private let upperLimitRow: [String]
    private let lowerLimitRow: [String]
    private var tabButtons: [NSButton] = []
    private var contentView: NSView!
    
    init(record: TestRecord, upperLimitRow: [String] = [], lowerLimitRow: [String] = []) {
        self.record = record
        self.upperLimitRow = upperLimitRow
        self.lowerLimitRow = lowerLimitRow
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - 数据辅助
    
    /// fail 测试项名称集合（从 testName 分号分隔解析）
    private var failNameSet: Set<String> {
        let names = record.testName.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(names)
    }
    
    /// fail 测试项名称列表（保持顺序）
    private var failNames: [String] {
        record.testName.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    /// 查找上限/下限值（通过 headerRow 列索引在 limit 行中定位）
    private func limitValue(for name: String, in limitRow: [String]) -> String {
        if let idx = record.headerRow.firstIndex(of: name), idx < limitRow.count {
            return limitRow[idx]
        }
        return ""
    }
    
    /// 所有测试项信息（通过 headerRow 解析）
    /// 返回 [(名称, 测量值, 上限值, 下限值, 状态)]
    private func allTestItems() -> [(name: String, value: String, upper: String, lower: String, status: String)] {
        var items: [(String, String, String, String, String)] = []
        let header = record.headerRow
        let row = record.rowData
        let failSet = failNameSet
        
        let startIdx = 13
        for i in startIdx..<min(header.count, row.count) {
            let name = header[i].trimmingCharacters(in: .whitespaces)
            let value = row[i].trimmingCharacters(in: .whitespaces)
            if name.isEmpty || value.isEmpty { continue }
            let status = failSet.contains(name) ? "FAIL" : "PASS"
            let upper = i < upperLimitRow.count ? upperLimitRow[i] : ""
            let lower = i < lowerLimitRow.count ? lowerLimitRow[i] : ""
            items.append((name, value, upper, lower, status))
        }
        return items
    }
    
    /// 仅 fail 测试项（通过 headerRow 查找对应值）
    private func failTestItems() -> [(name: String, value: String, upper: String, lower: String)] {
        var items: [(String, String, String, String)] = []
        let header = record.headerRow
        let row = record.rowData
        for name in failNames {
            var value = ""
            var upper = ""
            var lower = ""
            if let idx = header.firstIndex(of: name) {
                value = idx < row.count ? row[idx] : ""
                upper = idx < upperLimitRow.count ? upperLimitRow[idx] : ""
                lower = idx < lowerLimitRow.count ? lowerLimitRow[idx] : ""
            }
            items.append((name, value, upper, lower))
        }
        return items
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        let tabBar = NSView()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.wantsLayer = true
        tabBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(tabBar)
        
        let tabStack = NSStackView()
        tabStack.orientation = .horizontal
        tabStack.spacing = 0
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        tabBar.addSubview(tabStack)
        
        let infoTab = createTabButton(title: "基本信息", tag: "info")
        let allTab = createTabButton(title: "全部项目", tag: "all")
        let failTab = createTabButton(title: "仅Fail", tag: "fail")
        tabStack.addArrangedSubview(infoTab)
        tabStack.addArrangedSubview(allTab)
        tabStack.addArrangedSubview(failTab)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
        
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 36),
            
            tabStack.leadingAnchor.constraint(equalTo: tabBar.leadingAnchor, constant: 12),
            tabStack.centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            
            separator.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        switchTab("info")
    }
    
    private func createTabButton(title: String, tag: String) -> NSButton {
        let btn = NSButton(title: title, target: self, action: #selector(tabClicked(_:)))
        btn.bezelStyle = .rounded
        btn.identifier = NSUserInterfaceItemIdentifier(tag)
        btn.font = NSFont.systemFont(ofSize: 12)
        btn.isBordered = false
        btn.setButtonType(.momentaryChange)
        btn.widthAnchor.constraint(equalToConstant: 80).isActive = true
        tabButtons.append(btn)
        return btn
    }
    
    @objc private func tabClicked(_ sender: NSButton) {
        if let tag = sender.identifier?.rawValue {
            switchTab(tag)
        }
    }
    
    private func switchTab(_ tag: String) {
        for btn in tabButtons {
            let active = btn.identifier?.rawValue == tag
            btn.contentTintColor = active ? .controlAccentColor : nil
            btn.font = NSFont.systemFont(ofSize: 12, weight: active ? .medium : .regular)
        }
        
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        switch tag {
        case "info": showInfoTab()
        case "all":  showAllItemsTab()
        case "fail": showFailItemsTab()
        default: break
        }
    }
    
    // MARK: - 基本信息标签页
    private func showInfoTab() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack
        
        let simplePairs: [(String, String)] = [
            ("SN", record.sn),
            ("测试时间", record.testTime),
            ("SlotID", record.slotID),
            ("S_BUILD", record.sBuild),
            ("状态", record.status),
            ("Fail 测试项数", "\(failNames.count)"),
        ]
        for (label, value) in simplePairs {
            let row = makeSimpleRow(label: label, value: value)
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }
    
    private func makeSimpleRow(label: String, value: String) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        
        let labelField = NSTextField(labelWithString: label)
        labelField.font = NSFont.systemFont(ofSize: 11)
        labelField.textColor = .secondaryLabelColor
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(labelField)
        
        let valueField = NSTextField(labelWithString: value)
        valueField.font = NSFont.systemFont(ofSize: 12)
        valueField.lineBreakMode = .byTruncatingTail
        valueField.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valueField)
        
        if label == "状态" {
            valueField.textColor = value == "PASS" ? .systemGreen : (value == "FAIL" ? .systemRed : .labelColor)
            valueField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        }
        
        NSLayoutConstraint.activate([
            labelField.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 8),
            labelField.widthAnchor.constraint(equalToConstant: 100),
            labelField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            valueField.leadingAnchor.constraint(equalTo: labelField.trailingAnchor, constant: 12),
            valueField.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -8),
            valueField.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        
        return row
    }
    
    // MARK: - 全部项目标签页
    private func showAllItemsTab() {
        let items = allTestItems()
        let failCount = items.filter { $0.status == "FAIL" }.count
        let passCount = items.filter { $0.status == "PASS" }.count
        
        let countLabel = NSTextField(labelWithString: "共 \(items.count) 项（PASS: \(passCount), FAIL: \(failCount)）")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        let scrollView = createItemTableView(items: items)
        contentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            scrollView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }
    
    // MARK: - 仅Fail标签页
    private func showFailItemsTab() {
        let items = failTestItems()
        
        let countLabel = NSTextField(labelWithString: "共 \(items.count) 项 FAIL")
        countLabel.font = NSFont.systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)
        
        // 转为带状态的格式以复用表格创建
        let failItemsWithStatus = items.map { ($0.name, $0.value, $0.upper, $0.lower, "FAIL") }
        let scrollView = createItemTableView(items: failItemsWithStatus)
        contentView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            countLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            scrollView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }
    
    // MARK: - 通用测试项表格
    private func createItemTableView(items: [(name: String, value: String, upper: String, lower: String, status: String)]) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let tableView = NSTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 24
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        let columns: [(String, CGFloat)] = [
            ("#", 40),
            ("测试项", 300),
            ("状态", 60),
            ("测试值", 160),
            ("上限值", 120),
            ("下限值", 120),
            ("失败信息", 100),
        ]
        for (title, width) in columns {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            col.title = title
            col.width = width
            tableView.addTableColumn(col)
        }
        
        scrollView.documentView = tableView
        
        class ItemDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
            let items: [(name: String, value: String, upper: String, lower: String, status: String)]
            
            init(items: [(name: String, value: String, upper: String, lower: String, status: String)]) {
                self.items = items
            }
            
            func numberOfRows(in tableView: NSTableView) -> Int {
                return items.count
            }
            
            func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
                guard let column = tableColumn, row < items.count else { return nil }
                let item = items[row]
                let cellId = NSUserInterfaceItemIdentifier("DetailCell_\(column.identifier.rawValue)")
                var cell: NSTableCellView
                if let reused = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
                    cell = reused
                } else {
                    cell = NSTableCellView()
                    cell.identifier = cellId
                    let tf = NSTextField()
                    tf.isEditable = false
                    tf.isSelectable = true
                    tf.isBezeled = false
                    tf.drawsBackground = false
                    tf.font = NSFont.systemFont(ofSize: 11)
                    tf.translatesAutoresizingMaskIntoConstraints = false
                    tf.lineBreakMode = .byTruncatingTail
                    cell.addSubview(tf)
                    cell.textField = tf
                    NSLayoutConstraint.activate([
                        tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    ])
                }
                cell.textField?.textColor = NSColor.labelColor
                
                switch column.identifier.rawValue {
                case "#":
                    cell.textField?.stringValue = "\(row + 1)"
                case "测试项":
                    cell.textField?.stringValue = item.name
                case "状态":
                    cell.textField?.stringValue = item.status
                    cell.textField?.textColor = item.status == "PASS" ? .systemGreen : .systemRed
                case "测试值":
                    cell.textField?.stringValue = item.value
                    if item.status == "FAIL" {
                        cell.textField?.textColor = NSColor.systemRed
                    }
                case "上限值":
                    cell.textField?.stringValue = item.upper
                case "下限值":
                    cell.textField?.stringValue = item.lower
                case "失败信息":
                    cell.textField?.stringValue = item.status == "FAIL" ? "超出阈值" : ""
                    if item.status == "FAIL" {
                        cell.textField?.textColor = NSColor.systemRed
                    }
                default:
                    cell.textField?.stringValue = ""
                }
                return cell
            }
        }
        
        let delegate = ItemDelegate(items: items)
        tableView.dataSource = delegate
        tableView.delegate = delegate
        objc_setAssociatedObject(tableView, "detailDelegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        return scrollView
    }
}
