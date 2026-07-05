//
//  TabbedToolWindowController.swift
//  AtlasDataProcessorPlus
//
//  Created by gdlocal on 2026/7/2.
//

import Cocoa

/**
 监控汇总悬浮窗口控制器
 
 提供一个全局置顶的透明悬浮窗口，实时显示所有测试通道的状态汇总信息。
 窗口采用无边框透明设计，仅显示文字内容，不遮挡其他应用界面。
 
 - Note: 窗口通过 `window.isMovableByWindowBackground = true` 支持拖动移动
 - Warning: 窗口无标题栏，关闭需点击右上角 × 按钮或通过菜单重新打开
 */
class TabbedToolWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    
    /// 表格视图，用于展示通道汇总数据
    private var tableView: NSTableView!
    
    /// 关闭按钮，位于窗口右上角
    private var closeButton: NSTextField!
    
    /// 当前字体大小
    private var currentFontSize: Int {
        return AppConfig.shared.summaryFontSize
    }
    
    /// 当前字体颜色
    private var currentFontColor: NSColor {
        return NSColor(hexString: AppConfig.shared.summaryFontColor)
    }
    
    /// FAIL 颜色
    private var failColor: NSColor {
        return NSColor(hexString: AppConfig.shared.summaryFailColor)
    }
    
    /// PASS 颜色
    private var passColor: NSColor {
        return NSColor(hexString: AppConfig.shared.summaryPassColor)
    }
    
    /**
     指定初始化方法
     
     - Parameter window: 窗口实例
     - Warning: 调用前需确保窗口已正确配置样式和透明度
     */
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        setupUI()
        setupDataObserver()
    }
    
    /**
     更新配置后的刷新方法
     
     配置面板修改后调用此方法刷新窗口显示
     */
    func updateConfig() {
        #if DEBUG
        print("🔧 TabbedToolWindowController: updateConfig() 开始")
        print("🔧 当前字体大小: \(currentFontSize), 字体颜色: \(AppConfig.shared.summaryFontColor)")
        print("🔧 FAIL颜色: \(AppConfig.shared.summaryFailColor), PASS颜色: \(AppConfig.shared.summaryPassColor)")
        print("🔧 表格行数: \(tableView.numberOfRows), 列数: \(tableView.tableColumns.count)")
        #endif
        
        let fontSize = CGFloat(currentFontSize)
        tableView.rowHeight = fontSize + 10
        
        let columnWidths = TabbedToolWindowController.calculateColumnWidths(fontSize: fontSize)
        if let columns = tableView.tableColumns as? [NSTableColumn] {
            columns[0].width = columnWidths["channel"]!
            columns[1].width = columnWidths["status"]!
            columns[2].width = columnWidths["fail"]!
            columns[3].width = columnWidths["pass"]!
            columns[4].width = columnWidths["lastUpdate"]!
        }
        
        let newWidth = TabbedToolWindowController.calculateWindowWidth(fontSize: fontSize)
        let newHeight = TabbedToolWindowController.calculateWindowHeight(fontSize: fontSize)
        #if DEBUG
        print("🔧 新窗口尺寸: \(newWidth) x \(newHeight)")
        #endif
        
        if let window = window {
            window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: newWidth, height: newHeight), display: true)
        }
        
        for column in tableView.tableColumns {
            let identifier = column.identifier.rawValue
            for row in 0..<tableView.numberOfRows {
                if let cell = tableView.view(atColumn: tableView.column(withIdentifier: column.identifier), row: row, makeIfNecessary: true) as? NSTableCellView,
                   let textField = cell.textField {
                    let channels = getChannels()
                    if row < channels.count {
                        let channel = channels[row]
                        
                        if identifier == "status" {
                            switch channel.status {
                            case .running:
                                textField.textColor = NSColor.blue
                            case .waiting:
                                textField.textColor = NSColor.gray
                            case .ended:
                                textField.textColor = NSColor.green
                            case .stopped:
                                textField.textColor = NSColor.red
                            }
                        } else if identifier == "fail" {
                            textField.textColor = channel.failCount > 0 ? failColor : NSColor.green
                        } else if identifier == "pass" {
                            textField.textColor = passColor
                        } else {
                            textField.textColor = currentFontColor
                        }
                    } else {
                        textField.textColor = currentFontColor
                    }
                    textField.font = NSFont.systemFont(ofSize: fontSize, weight: identifier == "fail" || identifier == "pass" ? .bold : .medium)
                }
            }
        }
        
        tableView.reloadData()
        tableView.needsDisplay = true
        
        #if DEBUG
        print("🔧 TabbedToolWindowController: updateConfig() 完成")
        #endif
    }
    
    /**
     编码初始化方法（未实现）
     
     - Parameter coder: NSCoder 实例
     - Throws: 始终抛出 fatalError，此类不支持通过 Storyboard/XIB 创建
     */
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     创建并显示监控汇总窗口
     
     创建一个无边框透明窗口，设置为全局置顶，然后显示。
     
     - Returns: TabbedToolWindowController 实例
     - Note: 窗口初始位置为屏幕左上角，高度根据字体大小自动计算
     */
    static func createAndShow() -> TabbedToolWindowController {
        let fontSize = CGFloat(AppConfig.shared.summaryFontSize)
        let windowWidth = calculateWindowWidth(fontSize: fontSize)
        let windowHeight = calculateWindowHeight(fontSize: fontSize)
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        let configX = CGFloat(AppConfig.shared.summaryWindowX)
        let configY = CGFloat(AppConfig.shared.summaryWindowY)
        
        var originX = configX
        var originY = configY
        
        if configY > screenFrame.height {
            originY = screenFrame.height - windowHeight - 20
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "监控汇总"
        
        let controller = TabbedToolWindowController(window: window)
        controller.showWindow(nil)
        
        return controller
    }
    
    /**
     根据字体大小计算窗口高度
     
     - Parameter fontSize: 字体大小
     - Returns: 窗口高度
     */
    private static func calculateWindowHeight(fontSize: CGFloat) -> CGFloat {
        let dragBarHeight = fontSize + 10
        let minTableHeight: CGFloat = 150
        let padding: CGFloat = 20
        return dragBarHeight + minTableHeight + padding
    }
    
    /**
     动态计算每列的最大宽度
     
     根据当前通道数据的实际内容，计算每列需要的最大宽度
     
     - Parameter fontSize: 字体大小
     - Returns: 各列宽度字典 [列标识符: 宽度]
     */
    private static func calculateColumnWidths(fontSize: CGFloat) -> [String: CGFloat] {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let channels = MonitorManager.shared.getChannels()
        
        var maxWidths: [String: CGFloat] = [
            "channel": 0,
            "status": 0,
            "fail": 0,
            "pass": 0,
            "lastUpdate": 0
        ]
        
        for channel in channels {
            let channelWidth = "\(channel.name)".size(withAttributes: [.font: font]).width
            let statusWidth = "\(channel.status.rawValue)".size(withAttributes: [.font: font]).width
            let failWidth = "\(channel.failCount)".size(withAttributes: [.font: font]).width
            let passWidth = "\(channel.passCount)".size(withAttributes: [.font: font]).width
            let updateWidth = "\(channel.lastUpdate)".size(withAttributes: [.font: font]).width
            
            maxWidths["channel"] = max(maxWidths["channel"]!, channelWidth)
            maxWidths["status"] = max(maxWidths["status"]!, statusWidth)
            maxWidths["fail"] = max(maxWidths["fail"]!, failWidth)
            maxWidths["pass"] = max(maxWidths["pass"]!, passWidth)
            maxWidths["lastUpdate"] = max(maxWidths["lastUpdate"]!, updateWidth)
        }
        
        let spaceWidth = " ".size(withAttributes: [.font: font]).width
        for key in maxWidths.keys {
            maxWidths[key] = maxWidths[key]! + spaceWidth
        }
        
        return maxWidths
    }
    
    /**
     动态计算窗口宽度
     
     根据实际通道数据计算所有列宽度总和
     
     - Parameter fontSize: 字体大小
     - Returns: 窗口宽度
     */
    private static func calculateWindowWidth(fontSize: CGFloat) -> CGFloat {
        let widths = calculateColumnWidths(fontSize: fontSize)
        return widths.values.reduce(0, +) * 2
    }
    
    /**
     配置窗口属性
     
     设置窗口为全局置顶、透明背景、无阴影。
     窗口不可拖动，位置通过配置面板管理。
     设置 ignoresMouseEvents 实现鼠标穿透，不影响下方应用操作。
     */
    private func setupWindow() {
        window?.level = .floating
        window?.isOpaque = false
        window?.backgroundColor = NSColor.clear
        window?.hasShadow = false
        window?.ignoresMouseEvents = true
    }
    
    /**
     初始化界面组件
     
     创建透明的内容视图和表格视图，配置自动布局约束。
     配置项（字体大小、颜色、位置）通过独立配置面板管理。
     */
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        
        // 创建主容器视图
        let mainView = NSView()
        mainView.translatesAutoresizingMaskIntoConstraints = false
        mainView.wantsLayer = true
        mainView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.addSubview(mainView)
        
        NSLayoutConstraint.activate([
            mainView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        mainView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: mainView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: mainView.bottomAnchor)
        ])
        
        // 创建表格视图
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.gridStyleMask = []
        tableView.backgroundColor = NSColor.clear
        tableView.rowHeight = CGFloat(currentFontSize + 10)
        tableView.headerView = nil
        scrollView.documentView = tableView
        
        // 添加列：通道、状态、FAIL、PASS、最后更新
        let fontSize = CGFloat(currentFontSize)
        let columnWidths = TabbedToolWindowController.calculateColumnWidths(fontSize: fontSize)
        
        let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channel"))
        channelColumn.width = columnWidths["channel"]!
        tableView.addTableColumn(channelColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.width = columnWidths["status"]!
        tableView.addTableColumn(statusColumn)
        
        let failColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fail"))
        failColumn.width = columnWidths["fail"]!
        tableView.addTableColumn(failColumn)
        
        let passColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("pass"))
        passColumn.width = columnWidths["pass"]!
        tableView.addTableColumn(passColumn)
        
        let updateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUpdate"))
        updateColumn.width = columnWidths["lastUpdate"]!
        tableView.addTableColumn(updateColumn)
    }
    
    /**
     设置数据观察者
     
     监听 MonitorManager 的数据更新回调，刷新表格显示。
     数据更新时重新计算列宽，确保内容完整显示。
     */
    private func setupDataObserver() {
        MonitorManager.shared.onDataUpdate = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.tableView.reloadData()
                
                let fontSize = CGFloat(self.currentFontSize)
                let columnWidths = TabbedToolWindowController.calculateColumnWidths(fontSize: fontSize)
                if let columns = self.tableView.tableColumns as? [NSTableColumn] {
                    columns[0].width = columnWidths["channel"]!
                    columns[1].width = columnWidths["status"]!
                    columns[2].width = columnWidths["fail"]!
                    columns[3].width = columnWidths["pass"]!
                    columns[4].width = columnWidths["lastUpdate"]!
                }
                
                let newWidth = TabbedToolWindowController.calculateWindowWidth(fontSize: fontSize)
                let newHeight = TabbedToolWindowController.calculateWindowHeight(fontSize: fontSize)
                if let window = self.window {
                    window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: newWidth, height: newHeight), display: true)
                }
            }
        }
    }
    
    /**
     设置字体大小
     
     - Parameter sender: NSMenuItem 实例
     */
    @objc private func setFontSize(_ sender: NSMenuItem) {
        if let size = sender.representedObject as? Int {
            AppConfig.shared.summaryFontSize = size
            tableView.rowHeight = CGFloat(size + 10)
            closeButton.font = NSFont.systemFont(ofSize: CGFloat(size + 2), weight: .bold)
            
            // 更新列宽度
            let fontSize = CGFloat(size)
            let columnWidths = TabbedToolWindowController.calculateColumnWidths(fontSize: fontSize)
            if let columns = tableView.tableColumns as? [NSTableColumn] {
                columns[0].width = columnWidths["channel"]!
                columns[1].width = columnWidths["status"]!
                columns[2].width = columnWidths["fail"]!
                columns[3].width = columnWidths["pass"]!
                columns[4].width = columnWidths["lastUpdate"]!
            }
            
            tableView.reloadData()
            
            let newWidth = TabbedToolWindowController.calculateWindowWidth(fontSize: CGFloat(size))
            let newHeight = TabbedToolWindowController.calculateWindowHeight(fontSize: CGFloat(size))
            if let window = window {
                let screen = NSScreen.main ?? NSScreen.screens.first
                let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
                let newOriginY = max(screenFrame.height - newHeight - 20, 20)
                let newOriginX = min(window.frame.origin.x, screenFrame.width - newWidth - 20)
                window.setFrame(NSRect(x: newOriginX, y: newOriginY, width: newWidth, height: newHeight), display: true)
            }
        }
    }
    
    /**
     设置字体颜色
     
     - Parameter sender: NSMenuItem 实例
     */
    @objc private func setFontColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? String {
            AppConfig.shared.summaryFontColor = color
            tableView.reloadData()
        }
    }
    
    /**
     隐藏窗口
     
     隐藏当前窗口，控制器保持在后台运行，数据持续更新。
     */
    @objc private func closeWindow() {
        window?.orderOut(nil)
    }
    
    /**
     获取所有通道数据
     
     从 MonitorManager 获取通道数据。
     
     - Returns: 排序后的通道数组，按通道名称升序排列
     - Note: 通道名称格式为 "group-slot"
     */
    private func getChannels() -> [Channel] {
        return MonitorManager.shared.getChannels()
    }
    
    // MARK: - NSTableViewDataSource
    
    /**
     返回表格行数
     
     - Parameter tableView: NSTableView 实例
     - Returns: 通道数量
     */
    func numberOfRows(in tableView: NSTableView) -> Int {
        return getChannels().count
    }
    
    /**
     返回指定单元格的值
     
     - Parameter tableView: NSTableView 实例
     - Parameter tableColumn: 列对象
     - Parameter row: 行索引
     - Returns: 单元格显示的值（通道名/状态/FAIL数/PASS数/最后更新时间）
     */
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let channels = getChannels()
        guard row < channels.count, let identifier = tableColumn?.identifier.rawValue else {
            return nil
        }
        
        let channel = channels[row]
        
        switch identifier {
        case "channel":
            return channel.name
        case "status":
            return channel.status.rawValue
        case "fail":
            return channel.failCount
        case "pass":
            return channel.passCount
        case "lastUpdate":
            return channel.lastUpdate
        default:
            return nil
        }
    }
    
    // MARK: - NSTableViewDelegate
    
    /**
     创建并配置单元格视图
     
     - Parameter tableView: NSTableView 实例
     - Parameter tableColumn: 列对象
     - Parameter row: 行索引
     - Returns: 配置好的 NSTableCellView 实例
     - Note: 根据列类型设置不同的文字颜色和样式，使用配置文件中的字体大小和颜色
     */
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier.rawValue else {
            return nil
        }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
        
        if cell == nil {
            let newCell = NSTableCellView()
            newCell.identifier = cellIdentifier
            let textField = NSTextField(labelWithString: "")
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.alignment = .left
            newCell.textField = textField
            newCell.addSubview(textField)
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            
            cell = newCell
        }
        
        if let value = self.tableView(tableView, objectValueFor: tableColumn, row: row) {
            cell?.textField?.stringValue = "\(value)"
        }
        
        if let textField = cell?.textField {
            textField.font = NSFont.systemFont(ofSize: CGFloat(currentFontSize), weight: .medium)
            
            let channels = getChannels()
            if row < channels.count {
                let channel = channels[row]
                
                if identifier == "status" {
                    switch channel.status {
                    case .running:
                        textField.textColor = NSColor.blue
                    case .waiting:
                        textField.textColor = NSColor.gray
                    case .ended:
                        textField.textColor = NSColor.green
                    case .stopped:
                        textField.textColor = NSColor.red
                    }
                } else if identifier == "fail" {
                    textField.textColor = channel.failCount > 0 ? failColor : NSColor.green
                    textField.font = NSFont.systemFont(ofSize: CGFloat(currentFontSize), weight: .bold)
                } else if identifier == "pass" {
                    textField.textColor = passColor
                    textField.font = NSFont.systemFont(ofSize: CGFloat(currentFontSize), weight: .bold)
                } else {
                    textField.textColor = currentFontColor
                }
            } else {
                textField.textColor = currentFontColor
            }
            
            // #if DEBUG
            // if row == 0 && identifier == "channel" {
            //     print("🔧 tableView:viewFor:row: 行0,列\(identifier) - 字体大小:\(currentFontSize), 颜色:\(textField.textColor?.toHexString() ?? "nil")")
            // }
            // #endif
        }
        
        return cell
    }
}