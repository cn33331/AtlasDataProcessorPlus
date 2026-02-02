//
//  SummaryViewController.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Cocoa

class SummaryViewController: NSViewController {
    
    // MARK: - 属性
    
    weak var mainWindowController: MainWindowController?
    private var tableView: NSTableView!
    private var dataSource: [Channel] = []
    private var mainLayout: NSVStackLayout!
    
    // MARK: - 生命周期
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 视图加载完成后更新约束
        view.layoutSubtreeIfNeeded()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        // 确保表格视图正确显示
        tableView.sizeToFit()
    }
    
    // MARK: - UI 设置
    
    private func setupUI() {
        // 创建主布局
        // 自定义垂直堆叠布局容器 - 子视图之间的间距为 5像素 - 布局容器的内边距（上、左、下、右各 5像素）
        mainLayout = NSVStackLayout(spacing: 5, edgeInsets: NSEdgeInsets(top: 5, left: 5, bottom: 5, right: 5))
        // 垂直方向堆叠
        mainLayout.orientation = .vertical
        view.addSubview(mainLayout)
        
        // 设置主布局的约束 - 填满整个视图
        // - 左侧对齐- 右侧对齐- 顶部对齐- 底部对齐，自动填充整个左侧汇总区域的空间
        mainLayout.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainLayout.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainLayout.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainLayout.topAnchor.constraint(equalTo: view.topAnchor),
            mainLayout.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "所有通道汇总信息")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 12)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainLayout.addArrangedSubview(titleLabel)
        
        // 表格视图容器
        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autohidesScrollers = true
        
        // 设置最小高度
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        
        mainLayout.addArrangedSubview(scrollView)
        
        // 创建表格视图
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        
        // 设置表格样式
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
        tableView.rowHeight = 22
        tableView.headerView = NSTableHeaderView()
        
        // 添加列
        let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channel"))
        channelColumn.title = "通道"
        channelColumn.width = 80
        channelColumn.minWidth = 80
        channelColumn.maxWidth = 80
        tableView.addTableColumn(channelColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.title = "状态"
        statusColumn.width = 60
        statusColumn.minWidth = 60
        statusColumn.maxWidth = 60
        tableView.addTableColumn(statusColumn)
        
        let failColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fail"))
        failColumn.title = "FAIL"
        failColumn.width = 50
        failColumn.minWidth = 40
        failColumn.maxWidth = 60
        tableView.addTableColumn(failColumn)
        
        let passColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("pass"))
        passColumn.title = "PASS"
        passColumn.width = 50
        passColumn.minWidth = 40
        passColumn.maxWidth = 60
        tableView.addTableColumn(passColumn)
        
        let totalColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("total"))
        totalColumn.title = "总行数"
        totalColumn.width = 50
        totalColumn.minWidth = 40
        totalColumn.maxWidth = 60
        tableView.addTableColumn(totalColumn)
        
        let lastUpdateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUpdate"))
        lastUpdateColumn.title = "最后更新"
        lastUpdateColumn.width = 100
        lastUpdateColumn.minWidth = 80
        lastUpdateColumn.maxWidth = 150
        tableView.addTableColumn(lastUpdateColumn)
        
        // 设置表格为滚动视图的内容
        scrollView.documentView = tableView
        tableView.sizeLastColumnToFit()
        
        // 设置表格的自动布局
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // 通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tableViewDidResize(_:)),
            name: NSView.frameDidChangeNotification,
            object: tableView
        )
    }
    
    // MARK: - 数据操作
    
    func updateChannelStats(_ channel: Channel) {
        DispatchQueue.main.async {
            if let index = self.dataSource.firstIndex(where: { $0.name == channel.name }) {
                self.dataSource[index] = channel
                // 只更新对应行
                let columns = IndexSet(0..<self.tableView.numberOfColumns)
                self.tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: columns)
            } else {
                self.dataSource.append(channel)
                // 插入新行
                self.tableView.insertRows(at: IndexSet(integer: self.dataSource.count - 1), withAnimation: .slideDown)
            }
            
            // 滚动到最后一行
            if self.dataSource.count > 0 {
                self.tableView.scrollRowToVisible(self.dataSource.count - 1)
            }
        }
    }
    
    func updateMultipleChannels(_ channels: [Channel]) {
        DispatchQueue.main.async {
            var rowsToUpdate = IndexSet()
            
            for channel in channels {
                if let index = self.dataSource.firstIndex(where: { $0.name == channel.name }) {
                    self.dataSource[index] = channel
                    rowsToUpdate.insert(index)
                } else {
                    self.dataSource.append(channel)
                    rowsToUpdate.insert(self.dataSource.count - 1)
                }
            }
            
            if !rowsToUpdate.isEmpty {
                let columns = IndexSet(0..<self.tableView.numberOfColumns)
                self.tableView.reloadData(forRowIndexes: rowsToUpdate, columnIndexes: columns)
            }
        }
    }
    
    func clearAll() {
        dataSource.removeAll()
        tableView.reloadData()
    }
    
    // MARK: - 事件处理

    
    @objc private func tableViewDidResize(_ notification: Notification) {
        // 当表格大小改变时，调整最后一列的宽度
        tableView.sizeLastColumnToFit()
    }
    
    // MARK: - 辅助方法
    
    func getChannelCount() -> Int {
        return dataSource.count
    }
    
    func getTotalStats() -> (pass: Int, fail: Int, total: Int) {
        var totalPass = 0
        var totalFail = 0
        var totalCount = 0
        
        for channel in dataSource {
            totalPass += channel.passCount
            totalFail += channel.failCount
            totalCount += channel.totalCount
        }
        
        return (totalPass, totalFail, totalCount)
    }
    
    // MARK: - 内存管理
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - NSTableViewDataSource

extension SummaryViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < dataSource.count else { return nil }
        let channel = dataSource[row]
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        
        switch identifier {
        case "channel":
            return channel.name
        case "status":
            return channel.status.rawValue
        case "fail":
            return channel.failCount
        case "pass":
            return channel.passCount
        case "total":
            return channel.totalCount
        case "lastUpdate":
            return channel.lastUpdate
        default:
            return nil
        }
    }
    
    // 可选：支持排序
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let sortDescriptor = tableView.sortDescriptors.first else { return }
        
        dataSource.sort { channel1, channel2 in
            if sortDescriptor.key == "channel" {
                if sortDescriptor.ascending {
                    return channel1.name < channel2.name
                } else {
                    return channel1.name > channel2.name
                }
            } else if sortDescriptor.key == "status" {
                if sortDescriptor.ascending {
                    return channel1.status.rawValue < channel2.status.rawValue
                } else {
                    return channel1.status.rawValue > channel2.status.rawValue
                }
            }
            return true
        }
        
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDelegate

extension SummaryViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        
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
            let channel = dataSource[row]
            
            if identifier == "channel" {
                textField.textColor = NSColor.blue
                textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            } else if identifier == "status" {
                switch channel.status {
                case .running:
                    textField.textColor = NSColor.green
                case .ended:
                    textField.textColor = NSColor.blue
                case .stopped:
                    textField.textColor = NSColor.gray
                default:
                    textField.textColor = NSColor.black
                }
            } else if identifier == "fail" {
                textField.textColor = NSColor.red
                textField.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            } else if identifier == "pass" {
                textField.textColor = NSColor.green
                textField.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            } else if identifier == "total" {
                textField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            } else if identifier == "lastUpdate" {
                textField.font = NSFont.systemFont(ofSize: 10)
                textField.textColor = NSColor.darkGray
            }
            // 设置行背景色（只在第一列设置一次）每次渲染单元格
            if identifier == "channel" {
                if let rowView = cell.superview as? NSTableRowView {
                    if channel.failCount > 0 {
                        rowView.backgroundColor = NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
                    } else {
                        rowView.backgroundColor = NSColor.white
                    }
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }

    // 只在行视图首次添加时调用
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        // 为 FAIL 数目大于 0 的行设置背景色
        if row < dataSource.count {
            let channel = dataSource[row]
            if channel.failCount > 0 {
                rowView.backgroundColor = NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0)
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow >= 0 && tableView.selectedRow < dataSource.count {
            let channel = dataSource[tableView.selectedRow]
            print("选中通道: \(channel.name)")
            // 跳转到对应的通道详情标签页
            mainWindowController?.showChannelDetails(channel)
        }
    }
}
