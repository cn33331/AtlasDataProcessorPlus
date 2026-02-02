//
//  ChannelViewController.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Cocoa

class ChannelViewController: NSViewController {
    
    weak var mainWindowController: MainWindowController?
    let channel: Channel
    var autoScroll: Bool = true
    var showFailOnly: Bool = false
    
    // 暴露表格的可见行位置
    var visibleRow: Int {
        get {
            let visibleRect = tableView.visibleRect
            let visibleRows = tableView.rows(in: visibleRect)
            return visibleRows.location
        }
        set {
            if newValue >= 0 && newValue < tableView.numberOfRows {
                tableView.scrollRowToVisible(newValue)
            }
        }
    }
    
    // 滚动位置回调
    var onScrollPositionChanged: ((Int) -> Void)?
    
    private var isScrolling: Bool = false
    
    var tableView: NSTableView! // 改为公开属性，方便 MainWindowController 访问
    private var titleLabel: NSTextField!
    private var dataSource: [TestData] = []
    private var mainLayout: NSVStackLayout!
    
    init(channel: Channel) {
        self.channel = channel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateTitle()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        tableView.sizeToFit()
    }
    
    private func setupUI() {
        // 创建主布局 - NSVStackLayout 是 NSView 子类，所以用 addSubview
        mainLayout = NSVStackLayout(spacing: 8, edgeInsets: NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        mainLayout.orientation = .vertical
        view.addSubview(mainLayout)
        
        // 设置主布局的约束 - 填满整个视图
        mainLayout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainLayout.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainLayout.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainLayout.topAnchor.constraint(equalTo: view.topAnchor),
            mainLayout.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 标题栏
        titleLabel = NSTextField(labelWithString: "通道详情: \(channel.name)")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainLayout.addArrangedSubview(titleLabel)
        
        // 表格视图容器
        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // 设置最小高度
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        
        mainLayout.addArrangedSubview(scrollView)
        
        // 创建表格视图
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        
        // 设置表格样式
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.rowHeight = 22
        tableView.headerView = NSTableHeaderView()
        
        // 添加列
        let testNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("testName"))
        testNameColumn.title = "testName"
        testNameColumn.width = 500
        testNameColumn.minWidth = 600
        testNameColumn.maxWidth = 800
        tableView.addTableColumn(testNameColumn)
        
        let upperLimitColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("upperLimit"))
        upperLimitColumn.title = "upperLimit"
        upperLimitColumn.width = 60
        upperLimitColumn.minWidth = 50
        upperLimitColumn.maxWidth = 80
        tableView.addTableColumn(upperLimitColumn)
        
        let measurementValueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("measurementValue"))
        measurementValueColumn.title = "measurementValue"
        measurementValueColumn.width = 150
        measurementValueColumn.minWidth = 100
        measurementValueColumn.maxWidth = 200
        tableView.addTableColumn(measurementValueColumn)
        
        let lowerLimitColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lowerLimit"))
        lowerLimitColumn.title = "lowerLimit"
        lowerLimitColumn.width = 60
        lowerLimitColumn.minWidth = 50
        lowerLimitColumn.maxWidth = 80
        tableView.addTableColumn(lowerLimitColumn)
        
        let measurementUnitsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("measurementUnits"))
        measurementUnitsColumn.title = "measurementUnits"
        measurementUnitsColumn.width = 30
        measurementUnitsColumn.minWidth = 25
        measurementUnitsColumn.maxWidth = 40
        tableView.addTableColumn(measurementUnitsColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "status"
        statusColumn.width = 60
        statusColumn.minWidth = 50
        statusColumn.maxWidth = 70
        tableView.addTableColumn(statusColumn)
        
        // 设置表格为滚动视图的内容
        scrollView.documentView = tableView
        tableView.sizeLastColumnToFit()
        
        // 设置表格的自动布局
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // 上下文菜单
        let menu = NSMenu()
        let copyItem = NSMenuItem(title: "复制", action: #selector(copySelected), keyEquivalent: "c")
        menu.addItem(copyItem)
        
        // 添加导出到Excel菜单项
        let exportItem = NSMenuItem(title: "导出到Excel", action: #selector(exportToExcel), keyEquivalent: "e")
        menu.addItem(exportItem)
        
        tableView.menu = menu
        
        // 通知监听 - 表格大小变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tableViewDidResize(_:)),
            name: NSView.frameDidChangeNotification,
            object: tableView
        )
        
        // 通知监听 - 滚动视图滚动
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scrollView
        )
    }
    
    private func updateTitle() {
        let failCount = channel.testData.filter { $0.status == "FAIL" }.count
        let passCount = channel.testData.filter { $0.status == "PASS" }.count
        let totalCount = channel.testData.count
        
        titleLabel.stringValue = "通道详情: \(channel.name) | PASS: \(passCount) | FAIL: \(failCount) | 总数: \(totalCount)"
    }
    
    func updateTable() {
        // 过滤数据
        if showFailOnly {
            dataSource = channel.testData.filter { $0.status == "FAIL" }
        } else {
            dataSource = channel.testData
        }
        
        tableView.reloadData()
        
        // 更新标题
        updateTitle()
        
        // 自动滚动到底部
        if autoScroll && dataSource.count > 0 {
            tableView.scrollRowToVisible(dataSource.count - 1)
        }
    }
    
    @objc private func copySelected() {
        let selectedRows = tableView.selectedRowIndexes
        if selectedRows.isEmpty {
            return
        }
        
        var text = ""
        for row in selectedRows {
            guard row < dataSource.count else { continue }
            let testData = dataSource[row]
            let rowText = "\(testData.testName)\t\(testData.upperLimit)\t\(testData.measurementValue)\t\(testData.lowerLimit)\t\(testData.measurementUnits)\t\(testData.status)"
            text += rowText + "\n"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    @objc private func exportToExcel() {
        // 这里可以实现导出到Excel的功能
        print("导出到Excel功能待实现")
        
        // 示例：显示保存对话框
        let savePanel = NSSavePanel()
        savePanel.title = "导出到Excel"
        savePanel.message = "选择保存位置"
        savePanel.allowedContentTypes = [.spreadsheet]
        savePanel.nameFieldStringValue = "\(channel.name)_测试数据.xlsx"
        
        savePanel.begin { [weak self] result in
            if result == .OK, let url = savePanel.url {
                self?.exportDataToExcel(at: url)
            }
        }
    }
    
    private func exportDataToExcel(at url: URL) {
        // 实现实际的Excel导出逻辑
        // 可以使用第三方库如 CoreXLSX 或创建CSV文件
        var csvContent = "testName,upperLimit,measurementValue,lowerLimit,measurementUnits,status\n"
        
        for testData in dataSource {
            let row = "\(testData.testName),\(testData.upperLimit),\(testData.measurementValue),\(testData.lowerLimit),\(testData.measurementUnits),\(testData.status)\n"
            csvContent.append(row)
        }
        
        do {
            try csvContent.write(to: url, atomically: true, encoding: .utf8)
            print("数据已导出到: \(url.path)")
        } catch {
            print("导出失败: \(error)")
        }
    }
    
    @objc private func tableViewDidResize(_ notification: Notification) {
        tableView.sizeLastColumnToFit()
    }
    
    @objc private func scrollViewDidScroll(_ notification: Notification) {
        // 防止频繁回调
        if isScrolling {
            return
        }
        isScrolling = true
        
        // 延迟通知，避免滚动过程中频繁触发
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let currentRow = self.visibleRow
            self.onScrollPositionChanged?(currentRow)
            self.isScrolling = false
        }
    }
    
    // MARK: - 内存管理
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSTableViewDataSource

extension ChannelViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < dataSource.count else { return nil }
        let testData = dataSource[row]
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        
        switch identifier {
        case "testName":
            return testData.testName
        case "upperLimit":
            return testData.upperLimit
        case "measurementValue":
            return testData.measurementValue
        case "lowerLimit":
            return testData.lowerLimit
        case "measurementUnits":
            return testData.measurementUnits
        case "status":
            return testData.status
        default:
            return nil
        }
    }
}

// MARK: - NSTableViewDelegate

extension ChannelViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < dataSource.count, let identifier = tableColumn?.identifier.rawValue else { return nil }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = cellIdentifier
            let textField = NSTextField(labelWithString: "")
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            newCell.textField = textField
            newCell.addSubview(textField)
            
            // 设置文本字段约束
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            
            return newCell
        }()
        
        // 设置文本值
        if let value = self.tableView(tableView, objectValueFor: tableColumn, row: row) {
            cell.textField?.stringValue = "\(value)"
        }
        
        // 设置文本样式
        if let textField = cell.textField {
            let testData = dataSource[row]
            
            if identifier == "status" {
                if testData.status == "PASS" {
                    textField.textColor = NSColor.green
                    textField.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                } else if testData.status == "FAIL" {
                    textField.textColor = NSColor.red
                    textField.font = NSFont.systemFont(ofSize: 11, weight: .bold)
                }
            } else if identifier == "testName" {
                textField.font = NSFont.systemFont(ofSize: 11)
                textField.lineBreakMode = .byTruncatingTail
            } else if identifier == "measurementValue" {
                textField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            }
        }
        
        return cell
    }
    
    // ❌ 删除这个方法（不会被调用）在基于单元格模式下被调用
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        let testData = dataSource[row]
        
        if testData.status == "FAIL" {
            rowView.backgroundColor = NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
        }
        
        return rowView
    }

    // ✅ 使用这个方法（会被调用）基于视图模式
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if row < dataSource.count {
            let testData = dataSource[row]
            if testData.status == "FAIL" {
                rowView.backgroundColor = NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        // 可以在这里添加选中行变化的处理逻辑
        let selectedCount = tableView.selectedRowIndexes.count
        if selectedCount > 0 {
            print("选中了 \(selectedCount) 行")
        }
    }
}
