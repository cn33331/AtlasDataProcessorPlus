//
//  ChannelViewController.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Cocoa

class ChannelViewController: NSViewController {
    
    weak var mainWindowController: MainWindowController?
    var channel: Channel
    var autoScroll: Bool = true
    var showFailOnly: Bool = false
    
    /// 当前可见行位置（只读，基于表格可见区域计算）
    var visibleRow: Int {
        let visibleRect = tableView.visibleRect
        let visibleRows = tableView.rows(in: visibleRect)
        return visibleRows.location
    }
    
    var tableView: NSTableView! // 改为公开属性，方便 MainWindowController 访问
    private var titleLabel: NSTextField!
    
    // 结构体用于同时存储 TestData 和它的原始索引
    private struct TestDataWithIndex {
        let testData: TestData
        let originalIndex: Int
    }
    
    private var dataSource: [TestDataWithIndex] = []
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
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

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
        
        let rowNumberColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rowNumber"))
        rowNumberColumn.title = "#"
        rowNumberColumn.width = 40
        rowNumberColumn.minWidth = 30
        rowNumberColumn.maxWidth = 50
        tableView.addTableColumn(rowNumberColumn)
        
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
        
        
    }
    
    private func updateTitle() {
        let failCount = channel.testData.filter { $0.status == "FAIL" }.count
        let passCount = channel.testData.filter { $0.status == "PASS" }.count
        let totalCount = channel.testData.count
        
        titleLabel.stringValue = "通道详情: \(channel.name) | PASS: \(passCount) | FAIL: \(failCount) | 总数: \(totalCount)"
    }
    
    func updateTable() {
        rebuildDataSource()
        tableView.reloadData()
        updateTitle()
        
        // 自动滚动到底部
        if autoScroll && dataSource.count > 0 {
            tableView.scrollRowToVisible(dataSource.count - 1)
        }
    }
    
    private func rebuildDataSource() {
        if showFailOnly {
            dataSource = channel.testData.enumerated()
                .filter { $0.element.status == "FAIL" }
                .map { TestDataWithIndex(testData: $0.element, originalIndex: $0.offset) }
        } else {
            dataSource = channel.testData.enumerated()
                .map { TestDataWithIndex(testData: $0.element, originalIndex: $0.offset) }
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
            let item = dataSource[row]
            let testData = item.testData
            let rowText = "\(item.originalIndex + 1)\t\(testData.testName)\t\(testData.upperLimit)\t\(testData.measurementValue)\t\(testData.lowerLimit)\t\(testData.measurementUnits)\t\(testData.status)"
            text += rowText + "\n"
        }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    @objc private func exportToExcel() {
        // 导出为 CSV（带 UTF-8 BOM，Excel 可直接打开且中文不乱码）
        let savePanel = NSSavePanel()
        savePanel.title = "导出测试数据"
        savePanel.message = "保存为 CSV 文件（可用 Excel 打开）"
        savePanel.allowedFileTypes = ["csv"]
        savePanel.nameFieldStringValue = "\(channel.name)_测试数据.csv"
        
        savePanel.begin { [weak self] result in
            if result == .OK, let url = savePanel.url {
                self?.exportDataToExcel(at: url)
            }
        }
    }
    
    private func exportDataToExcel(at url: URL) {
        var csvContent = "#,testName,upperLimit,measurementValue,lowerLimit,measurementUnits,status\n"

        for item in dataSource {
            let testData = item.testData
            let cells = [
                "\(item.originalIndex + 1)",
                testData.testName,
                testData.upperLimit,
                testData.measurementValue,
                testData.lowerLimit,
                testData.measurementUnits,
                testData.status
            ]
            csvContent += cells.map { AtlasUtils.escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        AtlasUtils.writeCSV(csvContent, to: url, context: "导出数据")
    }
    
    @objc private func tableViewDidResize(_ notification: Notification) {
        tableView.sizeLastColumnToFit()
    }
    
    /**
     切换到指定通道
     
     切换通道时，保留当前表格的滚动位置、列宽等状态，
     仅替换数据源并刷新表格，实现同一位置对比不同通道数据。
     
     - Parameter newChannel: 目标通道
     */
    func switchToChannel(_ newChannel: Channel) {
        channel = newChannel
        rebuildDataSource()
        tableView.reloadData()
        updateTitle()
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
        let item = dataSource[row]
        let testData = item.testData
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
        case "rowNumber":
            return item.originalIndex + 1  // 使用原始索引，从1开始
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
            let item = dataSource[row]
            let testData = item.testData
            
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
            } else if identifier == "rowNumber" {
                textField.font = NSFont.systemFont(ofSize: 10, weight: .bold)
                textField.alignment = .center
            }
        }
        
        return cell
    }
    
    // ❌ 删除这个方法（不会被调用）在基于单元格模式下被调用
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        let item = dataSource[row]
        let testData = item.testData
        
        if testData.status == "FAIL" {
            rowView.backgroundColor = AtlasUtils.failRowBackground
        }

        return rowView
    }

    // ✅ 使用这个方法（会被调用）基于视图模式
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if row < dataSource.count {
            let item = dataSource[row]
            let testData = item.testData
            if testData.status == "FAIL" {
                rowView.backgroundColor = AtlasUtils.failRowBackground
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
