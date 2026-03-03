//
//  MainWindowController.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Cocoa

class MainWindowController: NSWindowController, DataReaderServiceDelegate, NSTabViewDelegate, NSSplitViewDelegate {
    
    private let basePath = URL(fileURLWithPath: "/Users/gdlocal/Library/Logs/Atlas/active")
    private var dataReaderService: DataReaderService!
    private var channelControllers: [String: ChannelViewController] = [:] // key: "group-slot"
    private var sharedScrollPosition: Int = 0 // 所有通道共享的滚动位置 滚动位置
    private var summaryViewController: SummaryViewController!
    
    // UI 组件声明 - 必须要有这些！
    private var splitView: NSSplitView!
    private var tabView: NSTabView!
    private var controlView: NSView!
    private var pathLabelTitle: NSTextField!
    private var pathLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var maxRowsTextField: NSTextField!
    private var maxRowsStepper: NSStepper!
    private var autoScrollCheckbox: NSButton!
    private var showFailOnlyCheckbox: NSButton!
    private var clearButton: NSButton!
    private var toggleSummaryButton: NSButton!
    private var statusBar: NSTextField!

    
    // 配置
    private var maxRows: Int = 1000
    private var autoScroll: Bool = true
    private var showFailOnly: Bool = false
    private var isSummaryVisible: Bool = true
    
    // ✅ 添加无参数初始化方法
    convenience init() {
        // 创建窗口
        let contentRect = NSRect(x: 0, y: 400, width: 1210, height: 450)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "测试平台数据监控工具"
        
        self.init(window: window)
        
        // 设置窗口代理
        window.delegate = self
        
        // 初始化 UI
        setupUI()
        setupDataReaderService()
        
        // 启动状态更新定时器
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateStatus), userInfo: nil, repeats: true)

    }
    
    // ✅ 正确的指定初始化方法
    override init(window: NSWindow?) {
        super.init(window: window)
        print("🎯 MainWindowController.init(window:) 被调用")
        
        // 注意：这里不要重新创建 window！
        // 使用传入的 window 或已在 convenience init 中创建的 window
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("✅ MainWindowController.windowDidLoad() - 窗口已加载")
        // 注意：此方法不会被调用，因为窗口是通过代码手动创建的
        // 如果将来改用 Xib/Storyboard 加载窗口，此方法会被自动调用
        // 目前监控已在 convenience init() 中手动启动

        // 确保窗口设置正确
        if let window = window {
            print("🪟 窗口标题: \(window.title)")
            print("📏 窗口尺寸: \(window.frame)")
        }
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        print("👁️ MainWindowController.showWindow() 被调用")
        
        // 确保窗口显示在最前
        window?.makeKeyAndOrderFront(sender)

        // 手动启动监控（因为 windowDidLoad() 不会在代码创建窗口时被调用）
        startMonitoring()

        // 延迟设置分割比例，确保视图布局完成后再设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.splitView.setPosition(220, ofDividerAt: 0)
    }

    }
    
    private func setupUI() {
        print("🛠️ 开始设置UI")
        // 获取窗口的内容视图容器
        let contentView = window!.contentView!
        // 启用图层支持，允许设置背景色
        contentView.wantsLayer = true
        // 设置白色背景
        contentView.layer?.backgroundColor = NSColor.white.cgColor
        
        // 控制面板
        // 调用子方法创建控制面板（包含所有按钮、输入框等）
        setupControlView()
        // 关键！ 禁用自动调整大小，启用 Auto Layout
        controlView.translatesAutoresizingMaskIntoConstraints = false
        // - 将控制面板添加到内容视图
        contentView.addSubview(controlView)
        
        // 分割视图
        // 创建分割视图容器
        splitView = NSSplitView()
        // isVertical = false ： 水平分割 （上下布局）， true 则为左右分割
        splitView.isVertical = true 
        // 分隔条样式为细线
        splitView.dividerStyle = .thin
        // 启用 Auto Layout
        splitView.translatesAutoresizingMaskIntoConstraints = false
        // 添加到内容视图
        contentView.addSubview(splitView)
        
        // 左侧：汇总信息
        // 创建一个容器视图
        let summaryView = NSView()
        summaryViewController = SummaryViewController()
        // 设置反向引用，方便通信
        summaryViewController.mainWindowController = self
        summaryView.addSubview(summaryViewController.view)
        summaryViewController.view.frame = summaryView.bounds
        // 允许视图随容器大小变化
        summaryViewController.view.autoresizingMask = [.width, .height]
        // 将容器添加到分割视图
        splitView.addSubview(summaryView)
        
        // 右侧：通道详情标签页
        tabView = NSTabView()
        // 顶部标签（最常见的）
//        tabView.tabType = .topTabsBezel
//        tabView.tabViewType = .topTabsBezelBorder
        // 当标签太长时允许截断显示
        tabView.allowsTruncatedLabels = true
        tabView.delegate = self
        splitView.addSubview(tabView)
        
        // 设置分割视图代理
        splitView.delegate = self
        
        // 状态栏
        statusBar = NSTextField(labelWithString: "监控已启动，正在扫描通道...")
        statusBar.alignment = .left
        statusBar.isEditable = false
        statusBar.isSelectable = false
        statusBar.font = NSFont.systemFont(ofSize: 12)
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusBar)
        
        // 设置布局约束
        NSLayoutConstraint.activate([
            // 控制面板约束
            controlView.topAnchor.constraint(equalTo: contentView.topAnchor),
            controlView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            controlView.heightAnchor.constraint(equalToConstant: 80),
            
            // 分割视图约束
            splitView.topAnchor.constraint(equalTo: controlView.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            // 状态栏约束
            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupControlView() {
        print("🔧 setupControlView() 开始")
        
        controlView = NSView()
        controlView.wantsLayer = true
        controlView.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1).cgColor
        
        // 先创建所有视图组件
        createAllViews()
        
        // 使用安全的约束方式
        setupSafeConstraints()
        
        print("✅ setupControlView() 完成")
    }

    private func createAllViews() {
        print("  ↪️ 创建所有视图组件")
        
        // 路径显示
        pathLabelTitle = NSTextField(labelWithString: "监控路径:")
        pathLabelTitle.font = NSFont.systemFont(ofSize: 12)
        pathLabelTitle.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(pathLabelTitle)
        
        pathLabel = NSTextField(string: basePath.path)
        pathLabel.isEditable = false
        pathLabel.isSelectable = true
        pathLabel.font = NSFont.systemFont(ofSize: 12)
        pathLabel.backgroundColor = NSColor.lightGray.withAlphaComponent(0.3)
        pathLabel.isBordered = true
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(pathLabel)
        
        // 监控控制
        startButton = NSButton(title: "开始监控", target: self, action: #selector(startMonitoring))
        startButton.bezelStyle = .rounded
        startButton.font = NSFont.systemFont(ofSize: 12)
        startButton.isEnabled = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(startButton)
        
        stopButton = NSButton(title: "停止监控", target: self, action: #selector(stopMonitoring))
        stopButton.bezelStyle = .rounded
        stopButton.font = NSFont.systemFont(ofSize: 12)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(stopButton)
        
        // 显示设置
        let maxRowsLabel = NSTextField(labelWithString: "最大行数:")
        maxRowsLabel.font = NSFont.systemFont(ofSize: 12)
        maxRowsLabel.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(maxRowsLabel)
        
        maxRowsTextField = NSTextField(string: "\(maxRows)")
        maxRowsTextField.isEditable = true
        maxRowsTextField.isSelectable = true
        maxRowsTextField.font = NSFont.systemFont(ofSize: 12)
        maxRowsTextField.backgroundColor = NSColor.white
        maxRowsTextField.isBordered = true
        maxRowsTextField.preferredMaxLayoutWidth = 60
        maxRowsTextField.alignment = .center
        maxRowsTextField.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(maxRowsTextField)
        
        maxRowsStepper = NSStepper()
        maxRowsStepper.minValue = 100
        maxRowsStepper.maxValue = 10000
        maxRowsStepper.increment = 100
        maxRowsStepper.intValue = Int32(maxRows)
        maxRowsStepper.target = self
        maxRowsStepper.action = #selector(maxRowsChanged)
        maxRowsStepper.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(maxRowsStepper)
        
        autoScrollCheckbox = NSButton(checkboxWithTitle: "自动滚动", target: self, action: #selector(autoScrollChanged))
        autoScrollCheckbox.state = .on
        autoScrollCheckbox.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(autoScrollCheckbox)
        
        showFailOnlyCheckbox = NSButton(checkboxWithTitle: "只显示FAIL行", target: self, action: #selector(showFailOnlyChanged))
        showFailOnlyCheckbox.state = .off
        showFailOnlyCheckbox.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(showFailOnlyCheckbox)
        
        clearButton = NSButton(title: "清除所有数据", target: self, action: #selector(clearAllData))
        clearButton.bezelStyle = .rounded
        clearButton.font = NSFont.systemFont(ofSize: 12)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(clearButton)
        
        toggleSummaryButton = NSButton(title: "隐藏汇总", target: self, action: #selector(toggleSummaryVisibility))
        toggleSummaryButton.bezelStyle = .rounded
        toggleSummaryButton.font = NSFont.systemFont(ofSize: 12)
        toggleSummaryButton.translatesAutoresizingMaskIntoConstraints = false
        controlView.addSubview(toggleSummaryButton)
    }

    private func setupSafeConstraints() {
        print("  ↪️ 设置安全约束")
        
        // 确保所有视图都已创建
        guard let pathLabelTitle = pathLabelTitle,
              let pathLabel = pathLabel,
              let startButton = startButton,
              let stopButton = stopButton,
              let maxRowsTextField = maxRowsTextField,
              let maxRowsStepper = maxRowsStepper,
              let autoScrollCheckbox = autoScrollCheckbox,
              let showFailOnlyCheckbox = showFailOnlyCheckbox,
              let clearButton = clearButton,
              let toggleSummaryButton = toggleSummaryButton else {
            print("❌ 错误：有些视图没有正确创建")
            return
        }
        
        // 找到 maxRowsLabel（局部变量）
        let maxRowsLabel = controlView.subviews.first { $0 is NSTextField && ($0 as! NSTextField).stringValue == "最大行数:" }
        
        guard let maxRowsLabel = maxRowsLabel else {
            print("❌ 错误：找不到 maxRowsLabel")
            return
        }
        
        var constraints: [NSLayoutConstraint] = []
        
        // 垂直居中约束
        constraints.append(contentsOf: [
            pathLabelTitle.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            pathLabel.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            startButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            stopButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            maxRowsLabel.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            maxRowsTextField.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            maxRowsStepper.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            autoScrollCheckbox.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            showFailOnlyCheckbox.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            clearButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            toggleSummaryButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor)
        ])
        
        // 水平约束 - 使用更简单的方式
        constraints.append(contentsOf: [
            // pathLabelTitle 左边距
            pathLabelTitle.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 8),
            
            // pathLabel 在 pathLabelTitle 右边
            pathLabel.leadingAnchor.constraint(equalTo: pathLabelTitle.trailingAnchor, constant: 8),
            pathLabel.widthAnchor.constraint(equalToConstant: 300),
            
            // startButton 在 pathLabel 右边
            startButton.leadingAnchor.constraint(equalTo: pathLabel.trailingAnchor, constant: 10),
            
            // stopButton 在 startButton 右边
            stopButton.leadingAnchor.constraint(equalTo: startButton.trailingAnchor, constant: 8),
            
            // maxRowsLabel 在 stopButton 右边
            maxRowsLabel.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 10),
            
            // maxRowsTextField 在 maxRowsLabel 右边
            maxRowsTextField.leadingAnchor.constraint(equalTo: maxRowsLabel.trailingAnchor, constant: 8),
            maxRowsTextField.widthAnchor.constraint(equalToConstant: 60),
            
            // maxRowsStepper 在 maxRowsTextField 右边
            maxRowsStepper.leadingAnchor.constraint(equalTo: maxRowsTextField.trailingAnchor, constant: 4),
            
            // autoScrollCheckbox 在 maxRowsStepper 右边
            autoScrollCheckbox.leadingAnchor.constraint(equalTo: maxRowsStepper.trailingAnchor, constant: 10),
            
            // showFailOnlyCheckbox 在 autoScrollCheckbox 右边
            showFailOnlyCheckbox.leadingAnchor.constraint(equalTo: autoScrollCheckbox.trailingAnchor, constant: 10),
            
            // clearButton 在 showFailOnlyCheckbox 右边
            clearButton.leadingAnchor.constraint(equalTo: showFailOnlyCheckbox.trailingAnchor, constant: 10),
            
            // toggleSummaryButton 在 clearButton 右边
            toggleSummaryButton.leadingAnchor.constraint(equalTo: clearButton.trailingAnchor, constant: 10),
            toggleSummaryButton.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -8)
        ])
        
        NSLayoutConstraint.activate(constraints)
        print("✅ 约束设置完成")
    }
    private func setupDataReaderService() {
        dataReaderService = DataReaderService(basePath: basePath)
        dataReaderService.delegate = self
    }
    
    @objc private func startMonitoring() {
        clearAllData()
        dataReaderService.start()
        startButton.isEnabled = false
        stopButton.isEnabled = true
        statusBar.stringValue = "监控已启动"
    }
    
    @objc public func stopMonitoring() {
        dataReaderService.stop()
        startButton.isEnabled = true
        stopButton.isEnabled = false
        
        // 更新所有通道状态
        for (_, controller) in channelControllers {
            controller.channel.status = .stopped
            summaryViewController.updateChannelStats(controller.channel)
        }
        
        statusBar.stringValue = "监控已停止"
    }
    
    @objc private func maxRowsChanged() {
        maxRows = Int(maxRowsStepper.intValue)
        maxRowsTextField.stringValue = "\(maxRows)"
        
        for (_, controller) in channelControllers {
            controller.channel.maxRows = maxRows
        }
    }
    
    @objc private func autoScrollChanged() {
        autoScroll = autoScrollCheckbox.state == .on
        
        for (_, controller) in channelControllers {
            controller.autoScroll = autoScroll
        }
        
        statusBar.stringValue = autoScroll ? "已启用自动滚动模式" : "已禁用自动滚动模式"
    }
    
    @objc private func showFailOnlyChanged() {
        showFailOnly = showFailOnlyCheckbox.state == .on
        
        for (_, controller) in channelControllers {
            controller.showFailOnly = showFailOnly
            controller.updateTable()
        }
        
        statusBar.stringValue = showFailOnly ? "已启用只显示FAIL行模式" : "已启用显示所有行模式"
    }
    
    @objc private func clearAllData() {
        for (_, controller) in channelControllers {
            controller.channel.clearData()
            controller.updateTable()
        }
        
        summaryViewController.clearAll()
        statusBar.stringValue = "所有数据已清除"
    }
    
    @objc private func toggleSummaryVisibility() {
        isSummaryVisible = !isSummaryVisible
        
        if isSummaryVisible {
            splitView.subviews[0].isHidden = false
            toggleSummaryButton.title = "隐藏汇总"
            splitView.setPosition(220, ofDividerAt: 0)
        } else {
            splitView.subviews[0].isHidden = true
            toggleSummaryButton.title = "显示汇总"
            splitView.setPosition(0, ofDividerAt: 0)
        }
    }
    
    @objc private func updateStatus() {
        let activeChannels = channelControllers.count
        
        if dataReaderService != nil {
            var status = "监控中 | 活动通道: \(activeChannels)"
            if showFailOnly {
                status += " | 只显示FAIL行"
            }
            statusBar.stringValue = status
        } else {
            statusBar.stringValue = "监控停止 | 活动通道: \(activeChannels)"
        }
    }
    
    // MARK: - DataReaderServiceDelegate
    
    func dataReaderService(_ service: DataReaderService, didFindNewDataForChannel channel: Channel, data: [TestData]) {
        DispatchQueue.main.async {
            let key = channel.name
            
            // 如果是新通道，创建显示组件
            if !self.channelControllers.keys.contains(key) {
                let channelController = ChannelViewController(channel: channel)
                channelController.mainWindowController = self
                channelController.autoScroll = self.autoScroll
                channelController.showFailOnly = self.showFailOnly
                
                // 设置滚动回调，更新共享的滚动位置
                channelController.onScrollPositionChanged = { [weak self] row in
                    guard let self = self else { return }
                    self.sharedScrollPosition = row
                    #if DEBUG
                    print("💾 更新共享滚动位置: \(row)")
                    #endif
                }
                
                self.channelControllers[key] = channelController
                
                // 添加到标签页
                let tabViewItem = NSTabViewItem(identifier: key)
                tabViewItem.label = channel.name
                tabViewItem.view = channelController.view
                self.tabView.addTabViewItem(tabViewItem)
                self.tabView.selectTabViewItem(tabViewItem)
                
                self.statusBar.stringValue = "发现新通道: \(channel.name)"
            }
            
            // 更新表格
            self.channelControllers[key]?.updateTable()
            
            // 更新汇总统计
            self.summaryViewController.updateChannelStats(channel)
        }
    }
    
    func dataReaderService(_ service: DataReaderService, didUpdateChannelStatus channel: Channel, status: Channel.ChannelStatus) {
        DispatchQueue.main.async {
            // 更新汇总统计
            self.summaryViewController.updateChannelStats(channel)
            
            if status == .ended {
                self.statusBar.stringValue = "通道 \(channel.name) 测试结束"
            }
        }
    }

    func dataReaderService(_ service: DataReaderService, didClearChannelData channel: Channel) {
        DispatchQueue.main.async {
            let key = channel.name
            if let controller = self.channelControllers[key] {
                controller.updateTable()
                self.summaryViewController.updateChannelStats(channel)
                self.statusBar.stringValue = "通道 \(channel.name) 开始新一轮测试，数据已清空"
                // 重置共享滚动位置
                self.sharedScrollPosition = 0
            }
        }
    }
    
    // MARK: - NSTabViewDelegate
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        #if DEBUG
        print("🔄 tabView(_:didSelect:) 被调用")
        print("📌 选中的标签页: \(tabViewItem?.label ?? "nil")")
        #endif
        
        // 当标签页被选中时，恢复共享的滚动位置
        if let identifier = tabViewItem?.identifier as? String {
            #if DEBUG
            print("🏷️ 标签页标识符: \(identifier)")
            #endif
            
            // 恢复新选中标签页的滚动位置
            if let controller = channelControllers[identifier] {
                #if DEBUG
                print("📊 新通道控制器: \(controller.channel.name)")
                print("   表格行数: \(controller.tableView.numberOfRows)")
                print("📍 共享滚动位置: \(sharedScrollPosition)")
                #endif
                
                // 使用共享的滚动位置，确保不超出范围
                let scrollRow = min(sharedScrollPosition, max(0, controller.tableView.numberOfRows - 1))
                
                if controller.tableView.numberOfRows > 0 && scrollRow >= 0 {
                    #if DEBUG
                    print("✅ 滚动到第 \(scrollRow) 行")
                    #endif
                    
                    controller.tableView.scrollRowToVisible(scrollRow)
                    
                    #if DEBUG
                    // 验证滚动是否成功
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let newVisibleRow = controller.visibleRow
                        print("🔍 滚动后可见行: \(newVisibleRow)")
                    }
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ 无法滚动：表格行数为 0 或滚动位置无效")
                    #endif
                }
            } else {
                #if DEBUG
                print("⚠️ 找不到通道控制器: \(identifier)")
                #endif
            }
        } else {
            #if DEBUG
            print("⚠️ 标签页标识符为 nil")
            #endif
        }
    }
    
    // MARK: - NSTabViewDelegate
    
    func tabView(_ tabView: NSTabView, shouldClose tabViewItem: NSTabViewItem) -> Bool {
        if let key = tabViewItem.identifier as? String {
            channelControllers.removeValue(forKey: key)
        }
        return true
    }
    
    // MARK: - Public Methods
    
    func showChannelDetails(_ channel: Channel) {
        let key = channel.name
        
        if let controller = channelControllers[key] {
            // 查找对应的标签页
            for tabViewItem in tabView.tabViewItems {
                if tabViewItem.identifier as? String == key {
                    tabView.selectTabViewItem(tabViewItem)
                    return
                }
            }
        } else {
            // 如果通道不存在，创建一个新的
            let channelController = ChannelViewController(channel: channel)
            channelController.mainWindowController = self
            channelController.autoScroll = autoScroll
            channelController.showFailOnly = showFailOnly
            
            // 设置滚动回调，更新共享的滚动位置
            channelController.onScrollPositionChanged = { [weak self] row in
                guard let self = self else { return }
                self.sharedScrollPosition = row
                #if DEBUG
                print("💾 更新共享滚动位置: \(row)")
                #endif
            }
            channelControllers[key] = channelController
            
            let tabViewItem = NSTabViewItem(identifier: key)
            tabViewItem.label = channel.name
            tabViewItem.view = channelController.view
            tabView.addTabViewItem(tabViewItem)
            tabView.selectTabViewItem(tabViewItem)
            
            statusBar.stringValue = "查看通道: \(channel.name)"
        }
    }

   // MARK: - NSSplitViewDelegate
    
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        // 限制左侧汇总区域的最大宽度为 220 像素
        if dividerIndex == 0 {
            return 220
        }
        return proposedMaximumPosition
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        // 限制左侧汇总区域的最小宽度为 0 像素
        if dividerIndex == 0 {
            return 0
        }
        return proposedMinimumPosition
    }

    // MARK: - NSWindowDelegate
    
    func windowDidResize(_ notification: Notification) {
        // 窗口尺寸变化时，确保左侧宽度不超过最大限制
        let maxLeftWidth: CGFloat = 220
        let currentLeftWidth = splitView.subviews[0].frame.width
        
        if currentLeftWidth > maxLeftWidth {
            splitView.setPosition(maxLeftWidth, ofDividerAt: 0)
        }
    }

}
// MARK: - NSWindowDelegate

extension MainWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopMonitoring()
    }
}