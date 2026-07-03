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
        let originX: CGFloat = 20
        let originY = screenFrame.height - windowHeight - 20
        
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
     根据字体大小计算列宽度
     
     - Parameter fontSize: 字体大小
     - Parameter maxChars: 最大字符数
     - Returns: 列宽度
     */
    private static func calculateColumnWidth(fontSize: CGFloat, maxChars: Int) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let testString = String(repeating: "w", count: maxChars)
        let width = testString.size(withAttributes: [.font: font]).width
        return width
    }
    
    /**
     根据字体大小计算所有列宽度总和
     
     - Parameter fontSize: 字体大小
     - Returns: 窗口宽度
     */
    private static func calculateWindowWidth(fontSize: CGFloat) -> CGFloat {
        let channelWidth = calculateColumnWidth(fontSize: fontSize, maxChars: 13)
        let statusWidth = calculateColumnWidth(fontSize: fontSize, maxChars: 5)
        let failWidth = calculateColumnWidth(fontSize: fontSize, maxChars: 4)
        let passWidth = calculateColumnWidth(fontSize: fontSize, maxChars: 4)
        let updateWidth = calculateColumnWidth(fontSize: fontSize, maxChars: 8)
        return channelWidth + statusWidth + failWidth + passWidth + updateWidth
    }
    
    /**
     配置窗口属性
     
     设置窗口为全局置顶、可拖动、透明背景、无阴影。
     */
    private func setupWindow() {
        window?.level = .floating
        window?.isMovableByWindowBackground = true
        window?.isOpaque = false
        window?.backgroundColor = NSColor.clear
        window?.hasShadow = false
    }
    
    /**
     初始化界面组件
     
     创建透明的内容视图、关闭按钮、拖动条和表格视图，配置自动布局约束。
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
        
        // 创建关闭按钮（使用 NSTextField 实现可点击效果）
        closeButton = NSTextField(labelWithString: "×")
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.font = NSFont.systemFont(ofSize: CGFloat(currentFontSize + 2), weight: .bold)
        closeButton.textColor = NSColor.gray
        closeButton.isEditable = false
        closeButton.isSelectable = false
        closeButton.isBordered = false
        closeButton.drawsBackground = false
        closeButton.sizeToFit()
        closeButton.wantsLayer = true
        
        // 添加点击手势
        let tapGesture = NSClickGestureRecognizer(target: self, action: #selector(closeWindow))
        closeButton.addGestureRecognizer(tapGesture)
        
        mainView.addSubview(closeButton)
        
        // 创建拖动条（用于移动窗口）
        let dragBar = NSView()
        dragBar.translatesAutoresizingMaskIntoConstraints = false
        dragBar.wantsLayer = true
        dragBar.layer?.backgroundColor = NSColor.clear.cgColor
        mainView.addSubview(dragBar)
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        mainView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -8),
            closeButton.topAnchor.constraint(equalTo: mainView.topAnchor, constant: 8),
            
            dragBar.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            dragBar.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            dragBar.topAnchor.constraint(equalTo: mainView.topAnchor),
            dragBar.heightAnchor.constraint(equalToConstant: CGFloat(currentFontSize + 10)),
            
            scrollView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: dragBar.bottomAnchor),
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
        
        // 右键菜单
        let menu = NSMenu()
        let fontSizeItem = NSMenuItem(title: "字体大小", action: nil, keyEquivalent: "")
        let fontSizeSubmenu = NSMenu()
        for size in [10, 12, 14, 16, 18, 20, 22, 24] {
            let item = NSMenuItem(title: "\(size)", action: #selector(setFontSize(_:)), keyEquivalent: "")
            item.representedObject = size
            fontSizeSubmenu.addItem(item)
        }
        fontSizeItem.submenu = fontSizeSubmenu
        menu.addItem(fontSizeItem)
        
        let fontColorItem = NSMenuItem(title: "字体颜色", action: nil, keyEquivalent: "")
        let fontColorSubmenu = NSMenu()
        let colors = [("黑色", "#000000"), ("白色", "#FFFFFF"), ("灰色", "#808080"), ("蓝色", "#0000FF")]
        for (name, hex) in colors {
            let item = NSMenuItem(title: name, action: #selector(setFontColor(_:)), keyEquivalent: "")
            item.representedObject = hex
            fontColorSubmenu.addItem(item)
        }
        fontColorItem.submenu = fontColorSubmenu
        menu.addItem(fontColorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let closeItem = NSMenuItem(title: "关闭", action: #selector(closeWindow), keyEquivalent: "")
        menu.addItem(closeItem)
        
        tableView.menu = menu
        
        // 添加列：通道、状态、FAIL、PASS、最后更新
        let fontSize = CGFloat(currentFontSize)
        let channelColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("channel"))
        channelColumn.width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 13)
        tableView.addTableColumn(channelColumn)
        
        let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusColumn.width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 5)
        tableView.addTableColumn(statusColumn)
        
        let failColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("fail"))
        failColumn.width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 4)
        tableView.addTableColumn(failColumn)
        
        let passColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("pass"))
        passColumn.width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 4)
        tableView.addTableColumn(passColumn)
        
        let updateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUpdate"))
        updateColumn.width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 8)
        tableView.addTableColumn(updateColumn)
    }
    
    /**
     设置数据观察者
     
     监听 MonitorManager 的数据更新回调，刷新表格显示。
     */
    private func setupDataObserver() {
        MonitorManager.shared.onDataUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.tableView.reloadData()
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
            if let columns = tableView.tableColumns as? [NSTableColumn] {
                columns[0].width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 13)
                columns[1].width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 5)
                columns[2].width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 4)
                columns[3].width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 4)
                columns[4].width = TabbedToolWindowController.calculateColumnWidth(fontSize: fontSize, maxChars: 8)
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
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView ?? {
            let newCell = NSTableCellView()
            newCell.identifier = cellIdentifier
            let textField = NSTextField(labelWithString: "")
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.alignment = .center
            newCell.textField = textField
            newCell.addSubview(textField)
            
            textField.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: newCell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: newCell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: newCell.centerYAnchor)
            ])
            
            return newCell
        }()
        
        if let value = self.tableView(tableView, objectValueFor: tableColumn, row: row) {
            cell.textField?.stringValue = "\(value)"
        }
        
        if let textField = cell.textField {
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
        }
        
        return cell
    }
}