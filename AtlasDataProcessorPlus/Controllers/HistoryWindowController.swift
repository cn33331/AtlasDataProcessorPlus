// HistoryWindowController.swift
import Cocoa

// 自定义表头视图，用于处理点击事件
class CustomTableHeaderView: NSTableHeaderView {
    var onColumnClick: ((NSTableColumn, NSEvent) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        #if DEBUG
        print("CustomTableHeaderView鼠标点击: \(event)")
        print("事件位置: \(event.locationInWindow)")
        print("表头边界: \(bounds)")
        #endif
        
        // 确定点击了哪一列
        let point = convert(event.locationInWindow, from: nil)
        #if DEBUG
        print("转换后的点: \(point)")
        #endif
        var clickedColumn: NSTableColumn?
        var currentX: CGFloat = 0
        
        if let tableView = tableView {
            for column in tableView.tableColumns {
                currentX += column.width
                if point.x <= currentX {
                    clickedColumn = column
                    break
                }
            }
            
            if let column = clickedColumn {
                #if DEBUG
                print("点击了列: \(column.identifier.rawValue)")
                #endif
                // 传递事件对象，以便在菜单显示时使用
                onColumnClick?(column, event)
            }
        }
    }
}

// 普通复选框，使用长按手势实现快速多选
class PressableCheckBox: NSButton {
    var onLongPress: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizer()
    }
    
    private func setupGestureRecognizer() {
        let pressGesture = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        pressGesture.minimumPressDuration = 0.2 // 长按时间阈值
        pressGesture.allowableMovement = 10 // 允许的移动范围
        addGestureRecognizer(pressGesture)
    }
    
    @objc private func handleLongPress(gesture: NSPressGestureRecognizer) {
        if gesture.state == .began {
            onLongPress?()
        }
    }
}

class HistoryWindowController: NSWindowController {
    
    // MARK: - UI 组件
    private var pathTextField: NSTextField!
    private var browseButton: NSButton!
    private var processButton: NSButton!
    private var statusLabel: NSTextField!
    private var tableView: NSTableView!
    private var resultTextView: NSTextView!
    private var saveCSVButton: NSButton!
    private var saveCSVPlusButton: NSButton!
    private var exportJSONButton: NSButton!
    
    // MARK: - 数据
    private var processor: AtlasDataProcessor?
    private var isProcessing = false
    private var statistics: [String: Any] = [:]
    private var failures: [String] = []
    private var processedData: [[String]] = []
    private var processedDataPlus: [[String]] = []
    
    // MARK: - 生命周期
    override func windowDidLoad() {
        #if DEBUG
        print("🔍 HistoryWindowController: windowDidLoad 被调用")
        print("📌 窗口标题: \(window?.title ?? "未知")")
        print("📐 窗口尺寸: \(window?.frame.size.width ?? 0) x \(window?.frame.size.height ?? 0)")
        #endif
        super.windowDidLoad()
        setupUI()
        #if DEBUG
        print("✅ HistoryWindowController: UI 设置完成")
        #endif
    }
    
    // MARK: - 初始化
    override init(window: NSWindow?) {
        #if DEBUG
        print("🏗️ HistoryWindowController: init 被调用")
        #endif
        super.init(window: window)
        
        // 如果窗口已经存在，立即设置UI
        if window != nil {
            #if DEBUG
            print("🔧 HistoryWindowController: 窗口已存在，立即设置UI")
            #endif
            setupUI()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        #if DEBUG
        print("🔧 HistoryWindowController: 开始设置UI")
        #endif
        guard let window = window else {
            #if DEBUG
            print("❌ HistoryWindowController: window 为空，无法设置UI")
            #endif
            return
        }
        
        // 主容器视图
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 垂直主布局
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.spacing = 20
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainStack)
        
        // 顶部控制面板
        let controlPanel = createControlPanel()
        mainStack.addArrangedSubview(controlPanel)
        
        // 表格视图（显示失败记录）
        let tableContainer = createTableView()
        mainStack.addArrangedSubview(tableContainer)
        
        // 底部操作按钮
        let actionButtons = createActionButtons()
        mainStack.addArrangedSubview(actionButtons)
        
        // 状态栏 - 独立添加，不放在堆栈视图中
        statusLabel = NSTextField(labelWithString: "准备就绪")
        statusLabel.alignment = .left
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // 设置窗口内容
        let viewController = NSViewController()
        viewController.view = containerView
        contentViewController = viewController
        
        // 设置窗口属性
        window.title = "Atlas 历史数据处理"
        window.setFrameAutosaveName("HistoryWindowFrame")
        window.minSize = NSSize(width: 900, height: 700)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 堆栈完整约束
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20), // ✅ 添加这个！
            
            // 表格视图最小高度
            tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        #if DEBUG
        print("✅ HistoryWindowController: UI 设置完成")
        print("📊 UI 组件数量: \(containerView.subviews.count)")
        #endif
    }
    
    // MARK: - 创建控制面板
    private func createControlPanel() -> NSView {
        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        
        // 路径标签
        let pathLabel = NSTextField(labelWithString: "数据目录:")
        pathLabel.font = NSFont.systemFont(ofSize: 12)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(pathLabel)
        
        // 路径输入框 - 设置默认值
        pathTextField = NSTextField()
        pathTextField.placeholderString = "请选择包含 records.csv 文件的目录"
        pathTextField.font = NSFont.systemFont(ofSize: 12)
        pathTextField.lineBreakMode = .byTruncatingHead
        pathTextField.stringValue = "/Users/gdlocal/Library/Logs/Atlas/unit-archive" // 设置默认值
        pathTextField.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(pathTextField)
        
        // 浏览按钮
        browseButton = NSButton(title: "浏览...", target: self, action: #selector(browseButtonClicked))
        browseButton.bezelStyle = .rounded
        browseButton.font = NSFont.systemFont(ofSize: 12)
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(browseButton)
        
        // 处理按钮
        processButton = NSButton(title: "开始处理", target: self, action: #selector(processButtonClicked))
        processButton.bezelStyle = .rounded
        processButton.keyEquivalent = "\r" // Return 键
        processButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        processButton.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(processButton)
        
        // 布局约束 - 所有组件放在同一排
        NSLayoutConstraint.activate([
            // 路径标签
            pathLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            pathLabel.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            pathLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // 路径输入框
            pathTextField.leadingAnchor.constraint(equalTo: pathLabel.trailingAnchor, constant: 10),
            pathTextField.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            pathTextField.heightAnchor.constraint(equalToConstant: 24),
            
            // 浏览按钮
            browseButton.leadingAnchor.constraint(equalTo: pathTextField.trailingAnchor, constant: 10),
            browseButton.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            browseButton.widthAnchor.constraint(equalToConstant: 80),
            
            // 处理按钮
            processButton.leadingAnchor.constraint(equalTo: browseButton.trailingAnchor, constant: 20),
            processButton.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
            processButton.widthAnchor.constraint(equalToConstant: 120),
            processButton.heightAnchor.constraint(equalToConstant: 32),
            
            // 面板高度约束
            panel.heightAnchor.constraint(equalToConstant: 60),
            processButton.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor)
        ])
        
        return panel
    }
    
    // MARK: - 创建表格视图
    // MARK: - 筛选和排序相关
    private var sortColumn: String?
    private var sortAscending: Bool = true
    private var filteredFailures: [String] = []
    private var filters: [String: Set<String>] = [:] // 列名 -> 筛选值集合
    
    private func createTableView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 标题
        let tableTitle = NSTextField(labelWithString: "失败记录")
        tableTitle.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tableTitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableTitle)
        
        // 提示：双击文件路径列的内容，打开文件所在路径
        let hintLabel = NSTextField(labelWithString: "提示：双击文件路径列的内容，打开文件所在路径--左键单击表头可进行数据筛选")
        hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .light)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hintLabel)
        
        // 滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        
        // 表格视图
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 40
        tableView.allowsColumnSelection = true
        
        // 使用自定义表头视图
        let customHeaderView = CustomTableHeaderView(frame: NSRect(x: 0, y: 0, width: 1000, height: 20))
        customHeaderView.tableView = tableView
        customHeaderView.onColumnClick = { [weak self] column, event in
            guard let self = self else { return }
            let columnName = column.identifier.rawValue
            #if DEBUG
            print("自定义表头回调: \(columnName)")
            print("传递的事件: \(event)")
            #endif
            self.showColumnContextMenu(columnName: columnName, event: event)
        }
        tableView.headerView = customHeaderView
        
        #if DEBUG
        print("表格视图委托设置: \(tableView.delegate != nil)")
        print("表格视图数据源设置: \(tableView.dataSource != nil)")
        print("使用自定义表头视图: \(tableView.headerView is CustomTableHeaderView)")
        #endif
        
        // 设置列
        let columns = [
            ("序号", 40),
            ("测试时间", 180),
            ("失败用例", 500),
            ("文件路径", 350)
        ]
        
        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = CGFloat(width)
            tableView.addTableColumn(column)
        }
        
        scrollView.documentView = tableView
        
        NSLayoutConstraint.activate([
            tableTitle.topAnchor.constraint(equalTo: container.topAnchor),
            tableTitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            hintLabel.topAnchor.constraint(equalTo: tableTitle.bottomAnchor, constant: 4),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        // 初始化筛选数据
        filteredFailures = failures
        
        return container
    }
    

    
    // 显示列上下文菜单
    private func showColumnContextMenu(columnName: String, event: NSEvent) {
        #if DEBUG
        print("显示列上下文菜单: \(columnName)")
        print("接收到的事件: \(event)")
        print("事件位置: \(event.locationInWindow)")
        #endif
        let menu = NSMenu(title: "")
        
        // 排序选项
        let sortAscendingItem = NSMenuItem(title: "升序排序", action: #selector(sortColumnAscending(_:)), keyEquivalent: "")
        sortAscendingItem.representedObject = columnName
        menu.addItem(sortAscendingItem)
        
        let sortDescendingItem = NSMenuItem(title: "降序排序", action: #selector(sortColumnDescending(_:)), keyEquivalent: "")
        sortDescendingItem.representedObject = columnName
        menu.addItem(sortDescendingItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 筛选选项
        let filterItem = NSMenuItem(title: "筛选", action: #selector(showFilterMenu(_:)), keyEquivalent: "")
        filterItem.representedObject = ["columnName": columnName, "event": event]
        menu.addItem(filterItem)
        
        // 重置筛选
        let resetFilterItem = NSMenuItem(title: "重置筛选", action: #selector(resetFilter(_:)), keyEquivalent: "")
        resetFilterItem.representedObject = columnName
        menu.addItem(resetFilterItem)
        
        // 显示菜单 - 使用传递的事件
        #if DEBUG
        print("使用传递的事件显示菜单")
        #endif
        if let headerView = tableView.headerView {
            #if DEBUG
            print("表头视图: \(headerView)")
            print("表头边界: \(headerView.bounds)")
            #endif
            NSMenu.popUpContextMenu(menu, with: event, for: headerView)
        } else if let contentView = window?.contentView {
            #if DEBUG
            print("使用内容视图显示菜单")
            #endif
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
        } else {
            #if DEBUG
            print("无法显示菜单: 没有合适的视图")
            #endif
        }
    }
    
    // 升序排序
    @objc private func sortColumnAscending(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        sortColumn = columnName
        sortAscending = true
        applySortAndFilter()
    }
    
    // 降序排序
    @objc private func sortColumnDescending(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        sortColumn = columnName
        sortAscending = false
        applySortAndFilter()
    }
    
    // 显示筛选菜单（使用NSPopover）
    @objc private func showFilterMenu(_ sender: NSMenuItem) {
        // 解析representedObject，它可能是字符串或字典
        var columnName: String?
        var event: NSEvent?
        
        if let dict = sender.representedObject as? [String: Any] {
            columnName = dict["columnName"] as? String
            event = dict["event"] as? NSEvent
            #if DEBUG
            print("从字典获取: columnName=\(columnName ?? "nil"), event=\(event != nil)")
            #endif
        } else if let str = sender.representedObject as? String {
            columnName = str
            event = NSApplication.shared.currentEvent
            #if DEBUG
            print("从字符串获取: columnName=\(str), 使用currentEvent: \(event != nil)")
            #endif
        }
        
        guard let columnName = columnName else { return }
        
        // 使用NSPopover实现筛选功能
        showFilterPopover(columnName: columnName, event: event)

    }
    
    // 显示筛选Popover
    private func showFilterPopover(columnName: String, event: NSEvent?) {
        // 创建Popover
        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .aqua)
        popover.animates = true
        
        // 计算Popover大小 - 增加默认大小
        let columnValues = getColumnValues(columnName: columnName)
        let height = min(CGFloat(40 + columnValues.count * 24 + 60), 500) // 增加最大高度到500
        let contentSize = NSSize(width: 800, height: height) // 增加默认宽度到800
        
        // 创建内容视图控制器
        let contentViewController = NSViewController()
        contentViewController.view = createFilterView(columnName: columnName, popover: popover)
        
        // 设置内容大小
        contentViewController.view.frame.size = contentSize
        popover.contentViewController = contentViewController
        
        // 强制设置内容大小
        popover.contentSize = contentSize
        
        // 显示Popover
        if let _ = event, let headerView = tableView.headerView {
            popover.show(relativeTo: headerView.bounds, of: headerView, preferredEdge: .maxY)
        } else if let window = self.window {
            popover.show(relativeTo: window.contentView!.bounds, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    // 为NSButton添加representedObject属性
    private var buttonRepresentedObjects = [NSButton: Any]()
    
    // 长按拖动多选相关
    private var isMultiSelectMode = false
    private var selectedCheckBoxes = Set<NSButton>()
    private var currentFilterColumn: String?
    private var currentPopover: NSPopover?
    private var scrollView: NSScrollView? // 用于自动滚动
    
    // 创建筛选视图
    private func createFilterView(columnName: String, popover: NSPopover) -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.cgColor
        
        // 设置最小宽度，确保Popover能够达到800宽度
        view.widthAnchor.constraint(greaterThanOrEqualToConstant: 800).isActive = true
        
        // 垂直堆栈视图
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.autoresizingMask = [.width, .height]
        view.addSubview(stackView)
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "筛选: \(columnName)")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.autoresizingMask = .width
        titleLabel.alignment = .left
        stackView.addArrangedSubview(titleLabel)
        
        // 全选按钮
        let selectAllButton = NSButton(title: "全选", target: self, action: #selector(selectAllInPopover(_:)))
        selectAllButton.bezelStyle = .texturedRounded
        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        selectAllButton.autoresizingMask = .width
        selectAllButton.alignment = .left
        buttonRepresentedObjects[selectAllButton] = ["columnName": columnName, "popover": popover]
        stackView.addArrangedSubview(selectAllButton)
        
        // 分隔线
        let separator1 = NSBox()
        separator1.boxType = .separator
        separator1.translatesAutoresizingMaskIntoConstraints = false
        separator1.autoresizingMask = .width
        stackView.addArrangedSubview(separator1)
        
        // 滚动视图用于选项
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.autoresizingMask = [.width, .height]
        
        // 选项容器
        let optionsView = NSView()
        optionsView.translatesAutoresizingMaskIntoConstraints = false
        optionsView.autoresizingMask = [.width, .height]
        
        // 垂直约束
        let optionsStackView = NSStackView()
        optionsStackView.orientation = .vertical
        optionsStackView.spacing = 4
        optionsStackView.alignment = .leading // 设置左对齐
        optionsStackView.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12) // 设置边距
        optionsStackView.translatesAutoresizingMaskIntoConstraints = false
        optionsStackView.autoresizingMask = .width
        optionsStackView.widthAnchor.constraint(equalToConstant: 768).isActive = true // 让StackView宽度撑满父视图
        optionsView.addSubview(optionsStackView)
        
        // 获取该列的所有唯一值
        let columnValues = getColumnValues(columnName: columnName)
        
        // 保存当前列名和popover
        currentFilterColumn = columnName
        currentPopover = popover
        
        // 添加各个选项
        for value in columnValues.sorted() {
            let checkBox = PressableCheckBox()
            checkBox.setButtonType(.switch)
            checkBox.title = value
            checkBox.target = self
            checkBox.action = #selector(toggleFilterValueInPopover(_:))
            checkBox.translatesAutoresizingMaskIntoConstraints = false
            checkBox.state = filters[columnName]?.contains(value) ?? false ? .on : .off
            buttonRepresentedObjects[checkBox] = ["column": columnName, "value": value]
            
            // 确保复选框能够适应宽度
            checkBox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            // 靠左对齐
            checkBox.alignment = .left
            
            // 添加长按手势处理
            checkBox.onLongPress = {
                [weak self] in
                self?.startMultiSelectMode()
            }
            
            optionsStackView.addArrangedSubview(checkBox)
        }
        
        scrollView.documentView = optionsView
        stackView.addArrangedSubview(scrollView)
        
        // 分隔线
        let separator2 = NSBox()
        separator2.boxType = .separator
        separator2.translatesAutoresizingMaskIntoConstraints = false
        separator2.autoresizingMask = .width
        stackView.addArrangedSubview(separator2)
        
        // 按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.autoresizingMask = .width
        
        // 水平堆栈视图用于按钮
        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 10
        buttonStackView.distribution = .fillEqually
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonStackView.autoresizingMask = .width
        buttonContainer.addSubview(buttonStackView)
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelFilter(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonRepresentedObjects[cancelButton] = popover
        buttonStackView.addArrangedSubview(cancelButton)
        
        // 确认按钮
        let confirmButton = NSButton(title: "确认", target: self, action: #selector(confirmFilter(_:)))
        confirmButton.bezelStyle = .rounded
        confirmButton.keyEquivalent = "\r"
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        buttonRepresentedObjects[confirmButton] = ["columnName": columnName, "popover": popover]
        buttonStackView.addArrangedSubview(confirmButton)
        
        stackView.addArrangedSubview(buttonContainer)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 堆栈视图约束
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            
            // 选项视图约束
            optionsStackView.leadingAnchor.constraint(equalTo: optionsView.leadingAnchor),
            optionsStackView.trailingAnchor.constraint(equalTo: optionsView.trailingAnchor),
            optionsStackView.topAnchor.constraint(equalTo: optionsView.topAnchor),
            optionsStackView.bottomAnchor.constraint(equalTo: optionsView.bottomAnchor),
            
            // 滚动视图约束 - 移除最大高度限制，允许拉伸
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            // 按钮容器约束
            buttonStackView.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            buttonStackView.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            buttonStackView.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            buttonStackView.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            
            // 按钮容器高度约束
            buttonContainer.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        return view
    }
    
    // 全选Popover中的选项
    @objc private func selectAllInPopover(_ sender: NSButton) {
        guard let data = buttonRepresentedObjects[sender] as? [String: Any],
              let columnName = data["columnName"] as? String else { return }
        
        let columnValues = getColumnValues(columnName: columnName)
        
        // 切换全选状态
        if filters[columnName] == nil || (filters[columnName]?.count ?? 0) < columnValues.count {
            // 全选
            filters[columnName] = Set(columnValues)
        } else {
            // 取消全选
            filters.removeValue(forKey: columnName)
        }
        
        // 重新显示Popover以更新状态
        if let popover = data["popover"] as? NSPopover {
            popover.performClose(sender)
            showFilterPopover(columnName: columnName, event: nil)
        }
    }
    
    // 切换Popover中的筛选值
    @objc private func toggleFilterValueInPopover(_ sender: NSButton) {
        guard let data = buttonRepresentedObjects[sender] as? [String: String],
              let columnName = data["column"],
              let value = data["value"] else { return }
        
        // 初始化筛选集合
        if filters[columnName] == nil {
            filters[columnName] = Set()
        }
        
        // 切换值
        if sender.state == .on {
            filters[columnName]!.insert(value)
        } else {
            filters[columnName]!.remove(value)
        }
        
        // 如果该列没有筛选值，移除该列的筛选
        if filters[columnName]!.isEmpty {
            filters.removeValue(forKey: columnName)
        }
    }
    
    // 取消筛选
    @objc private func cancelFilter(_ sender: NSButton) {
        if let popover = buttonRepresentedObjects[sender] as? NSPopover {
            popover.performClose(sender)
        }
    }
    
    // 确认筛选
    @objc private func confirmFilter(_ sender: NSButton) {
        guard let data = buttonRepresentedObjects[sender] as? [String: Any],
              let popover = data["popover"] as? NSPopover else { return }
        
        // 应用筛选
        applySortAndFilter()
        
        // 关闭Popover
        popover.performClose(sender)
    }
    
    // 开始多选模式
    private func startMultiSelectMode() {
        isMultiSelectMode = true
        selectedCheckBoxes.removeAll()
        
        // 开始监听鼠标事件
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp(event)
            return event
        }
    }
    
    // 处理鼠标拖动
    private func handleMouseDragged(_ event: NSEvent) {
        if !isMultiSelectMode { return }
        
        // 获取鼠标位置
        let mouseLocation = event.locationInWindow
        
        // 碰撞检测
        detectCheckBoxes(at: mouseLocation)
        
        // 自动滚动
        handleAutoScroll(at: mouseLocation)
    }
    
    // 碰撞检测
    private func detectCheckBoxes(at location: NSPoint) {
        guard let popover = currentPopover, let contentView = popover.contentViewController?.view else { return }
        
        // 遍历所有子视图，找到所有的PressableCheckBox
        func findCheckBoxes(in view: NSView) -> [PressableCheckBox] {
            var checkBoxes: [PressableCheckBox] = []
            for subview in view.subviews {
                if let checkBox = subview as? PressableCheckBox {
                    checkBoxes.append(checkBox)
                } else {
                    checkBoxes.append(contentsOf: findCheckBoxes(in: subview))
                }
            }
            return checkBoxes
        }
        
        let checkBoxes = findCheckBoxes(in: contentView)
        
        // 遍历所有复选框
        for checkBox in checkBoxes {
            // 转换鼠标位置到复选框坐标系
            let localPoint = checkBox.convert(location, from: nil)
            
            // 检查是否在复选框范围内
            if checkBox.bounds.contains(localPoint) && !selectedCheckBoxes.contains(checkBox) {
                // 切换状态
                checkBox.state = .on
                selectedCheckBoxes.insert(checkBox)
                
                // 触发action
                if let action = checkBox.action, let target = checkBox.target {
                    NSApp.sendAction(action, to: target, from: checkBox)
                }
            }
        }
    }
    
    // 自动滚动
    private func handleAutoScroll(at location: NSPoint) {
        guard let popover = currentPopover, let contentView = popover.contentViewController?.view else { return }
        
        // 遍历所有子视图，找到滚动视图
        func findScrollView(in view: NSView) -> NSScrollView? {
            for subview in view.subviews {
                if let scrollView = subview as? NSScrollView {
                    return scrollView
                } else if let foundScrollView = findScrollView(in: subview) {
                    return foundScrollView
                }
            }
            return nil
        }
        
        guard let scrollView = findScrollView(in: contentView) else { return }
        
        let scrollViewFrame = scrollView.frame
        let scrollViewLocation = scrollView.convert(location, from: nil)
        
        // 检查是否需要滚动
        let scrollThreshold: CGFloat = 20
        let scrollSpeed: CGFloat = 5
        
        if scrollViewLocation.y < scrollThreshold {
            // 向上滚动
            scrollView.contentView.scroll(NSPoint(x: 0, y: -scrollSpeed))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        } else if scrollViewLocation.y > scrollViewFrame.height - scrollThreshold {
            // 向下滚动
            scrollView.contentView.scroll(NSPoint(x: 0, y: scrollSpeed))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
    
    // 处理鼠标释放
    private func handleMouseUp(_ event: NSEvent) {
        isMultiSelectMode = false
        selectedCheckBoxes.removeAll()
    }
    
    // 切换筛选值
    @objc private func toggleFilterValue(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: String],
              let columnName = data["column"],
              let value = data["value"] else { return }
        
        if value == "__SELECT_ALL__" {
            // 处理全选/取消全选
            let columnValues = getColumnValues(columnName: columnName)
            
            if filters[columnName] == nil || (filters[columnName]?.count ?? 0) < columnValues.count {
                // 全选
                filters[columnName] = Set(columnValues)
            } else {
                // 取消全选
                filters.removeValue(forKey: columnName)
            }
        } else {
            // 处理单个值的切换
            if filters[columnName] == nil {
                filters[columnName] = Set()
            }
            
            if filters[columnName]!.contains(value) {
                filters[columnName]!.remove(value)
            } else {
                filters[columnName]!.insert(value)
            }
            
            // 如果该列没有筛选值，移除该列的筛选
            if filters[columnName]!.isEmpty {
                filters.removeValue(forKey: columnName)
            }
        }
        
        applySortAndFilter()
    }
    
    // 切换临时全选
    @objc private func toggleSelectAllInTemp(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let columnName = data["columnName"] as? String,
              let selections = data["selections"] as? NSMutableSet,
              let allValues = data["allValues"] as? Set<String> else { return }
        
        if selections.count == allValues.count {
            // 取消全选
            selections.removeAllObjects()
        } else {
            // 全选
            selections.removeAllObjects()
            selections.addObjects(from: Array(allValues))
        }
        
        // 更新菜单项状态
        sender.state = selections.count == allValues.count ? .on : .off
    }
    
    // 切换临时值
    @objc private func toggleValueInTemp(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let columnName = data["columnName"] as? String,
              let value = data["value"] as? String,
              let selections = data["selections"] as? NSMutableSet else { return }
        
        if selections.contains(value) {
            selections.remove(value)
        } else {
            selections.add(value)
        }
        
        // 更新菜单项状态
        sender.state = selections.contains(value) ? .on : .off
    }
    
    // 确认筛选选择
    @objc private func confirmFilterSelection(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let columnName = data["columnName"] as? String,
              let selections = data["selections"] as? NSMutableSet else { return }
        
        if selections.count > 0 {
            filters[columnName] = selections as? Set<String>
        } else {
            filters.removeValue(forKey: columnName)
        }
        
        applySortAndFilter()
        tableView.reloadData()
    }
    
    // 重置筛选
    @objc private func resetFilter(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        filters.removeValue(forKey: columnName)
        applySortAndFilter()
    }
    
    // 全选筛选值
    @objc private func selectAllFilterValues(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let columnName = data["columnName"] as? String else { return }
        
        let columnValues = getColumnValues(columnName: columnName)
        
        if filters[columnName] == nil || (filters[columnName]?.count ?? 0) < columnValues.count {
            // 全选
            filters[columnName] = Set(columnValues)
        } else {
            // 取消全选
            filters.removeValue(forKey: columnName)
        }
        
        applySortAndFilter()
    }
    
    // 清除筛选
    @objc private func clearFilter(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? [String: Any],
              let columnName = data["columnName"] as? String else { return }
        
        filters.removeValue(forKey: columnName)
        applySortAndFilter()
    }
    
    // 获取列的所有值
    private func getColumnValues(columnName: String) -> Set<String> {
        var values: Set<String> = []
        
        for (index, failure) in failures.enumerated() {
            let value = getCellValue(for: columnName, row: index, useOriginalData: true)
            if !value.isEmpty {
                values.insert(value)
            }
        }
        
        return values
    }
    
    // 应用排序和筛选
    private func applySortAndFilter() {
        // 应用筛选 - 使用临时数组
        var tempFilteredFailures = failures.filter { failure in
            let rowIndex = failures.firstIndex(of: failure) ?? 0
            
            // 检查所有筛选条件
            for (columnName, filterValues) in filters {
                // 直接从原始failures数组获取值，避免访问filteredFailures
                let components = failure.components(separatedBy: " | ")
                var value: String = ""
                
                switch columnName {
                case "序号":
                    value = "\(rowIndex + 1)"
                case "测试时间":
                    value = components.count > 0 ? components[0] : "未知时间"
                case "失败用例":
                    value = components.count > 1 ? components[1] : "无具体用例"
                case "文件路径":
                    value = components.count > 2 ? components[2] : "未知文件"
                default:
                    value = ""
                }
                
                if !filterValues.contains(value) {
                    return false
                }
            }
            
            return true
        }
        
        // 应用排序
        if let sortColumn = sortColumn {
            tempFilteredFailures.sort { failure1, failure2 in
                // 直接从原始数据获取值，避免访问filteredFailures
                let components1 = failure1.components(separatedBy: " | ")
                let components2 = failure2.components(separatedBy: " | ")
                
                var value1: String = ""
                var value2: String = ""
                
                switch sortColumn {
                case "序号":
                    let index1 = failures.firstIndex(of: failure1) ?? 0
                    let index2 = failures.firstIndex(of: failure2) ?? 0
                    value1 = "\(index1 + 1)"
                    value2 = "\(index2 + 1)"
                case "测试时间":
                    value1 = components1.count > 0 ? components1[0] : "未知时间"
                    value2 = components2.count > 0 ? components2[0] : "未知时间"
                case "失败用例":
                    value1 = components1.count > 1 ? components1[1] : "无具体用例"
                    value2 = components2.count > 1 ? components2[1] : "无具体用例"
                case "文件路径":
                    value1 = components1.count > 2 ? components1[2] : "未知文件"
                    value2 = components2.count > 2 ? components2[2] : "未知文件"
                default:
                    value1 = ""
                    value2 = ""
                }
                
                if sortAscending {
                    return value1 < value2
                } else {
                    return value1 > value2
                }
            }
        }
        
        // 最后一次性更新filteredFailures
        filteredFailures = tempFilteredFailures
        
        // 更新表格
        tableView.reloadData()
    }
    
    // MARK: - 创建操作按钮
    private func createActionButtons() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        // 保存 CSV 按钮
        saveCSVButton = NSButton(title: "保存 CSV", target: self, action: #selector(saveCSVButtonClicked))
        saveCSVButton.bezelStyle = .rounded
        saveCSVButton.isEnabled = false
        stack.addArrangedSubview(saveCSVButton)
        
        // 保存 CSV Plus 按钮
        saveCSVPlusButton = NSButton(title: "保存 CSV Plus", target: self, action: #selector(saveCSVPlusButtonClicked))
        saveCSVPlusButton.bezelStyle = .rounded
        saveCSVPlusButton.isEnabled = false
        stack.addArrangedSubview(saveCSVPlusButton)
        
        // 导出 JSON 按钮
        exportJSONButton = NSButton(title: "导出 JSON", target: self, action: #selector(exportJSONButtonClicked))
        exportJSONButton.bezelStyle = .rounded
        exportJSONButton.isEnabled = false
        stack.addArrangedSubview(exportJSONButton)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return container
    }
    
    // MARK: - 按钮动作
    @objc private func browseButtonClicked() {
        #if DEBUG
        print("📂 HistoryWindowController: 浏览按钮被点击")
        #endif
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择目录"
        openPanel.message = "请选择包含 records.csv 文件的目录"
        
        openPanel.beginSheetModal(for: window!) { [weak self] response in
            #if DEBUG
            print("📂 HistoryWindowController: 文件选择面板响应: \(response == .OK ? "OK" : "Cancel")")
            #endif
            guard response == .OK, let url = openPanel.url else { return }
            self?.pathTextField.stringValue = url.path
            #if DEBUG
            print("📂 HistoryWindowController: 选择的目录: \(url.path)")
            #endif
        }
    }
    
    @objc private func processButtonClicked() {
        let path = pathTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !path.isEmpty else {
            showAlert(title: "错误", message: "请先选择数据目录")
            return
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            showAlert(title: "错误", message: "目录不存在")
            return
        }
        
        startProcessing(path: path)
    }
    
    @objc private func saveCSVButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "AtlasCombineData_\(processor.getTimestamp()).csv"
        savePanel.message = "选择保存 CSV 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                // 构建 CSV 内容
                let csvContent = self?.processedData.map { row in
                    row.map { cell in
                        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                            let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        return cell
                    }.joined(separator: ",")
                }.joined(separator: "\n")
                
                try csvContent?.write(to: url, atomically: true, encoding: .utf8)
                self?.showAlert(title: "成功", message: "CSV 文件已保存到: \(url.path)")
                
            } catch {
                self?.showAlert(title: "保存失败", message: "无法保存文件: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func saveCSVPlusButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "AtlasCombineData_Plus_\(processor.getTimestamp()).csv"
        savePanel.message = "选择保存 CSV Plus 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            do {
                // 构建 CSV Plus 内容
                let csvContent = self?.processedDataPlus.map { row in
                    row.map { cell in
                        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
                            let escaped = cell.replacingOccurrences(of: "\"", with: "\"\"")
                            return "\"\(escaped)\""
                        }
                        return cell
                    }.joined(separator: ",")
                }.joined(separator: "\n")
                
                try csvContent?.write(to: url, atomically: true, encoding: .utf8)
                self?.showAlert(title: "成功", message: "CSV Plus 文件已保存到: \(url.path)")
                
            } catch {
                self?.showAlert(title: "保存失败", message: "无法保存文件: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func exportJSONButtonClicked() {
        guard let processor = processor else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "AtlasAnalysis_\(processor.getTimestamp()).json"
        savePanel.message = "选择保存 JSON 文件的位置"
        
        savePanel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = savePanel.url else { return }
            
            // 使用处理器的导出功能
            if let _ = processor.exportToJSON(outputDir: url.deletingLastPathComponent().path) {
                self?.showAlert(title: "成功", message: "JSON 文件已保存到: \(url.path)")
            } else {
                self?.showAlert(title: "导出失败", message: "无法导出 JSON 文件")
            }
        }
    }
    
    // MARK: - 数据处理
    private func startProcessing(path: String) {
        guard !isProcessing else { return }
        
        isProcessing = true
        processButton.isEnabled = false
        browseButton.isEnabled = false
        statusLabel.stringValue = "正在处理数据..."
        
        // 重置按钮状态
        saveCSVButton.isEnabled = false
        saveCSVPlusButton.isEnabled = false
        exportJSONButton.isEnabled = false
        
        // 创建新的处理器实例
        processor = AtlasDataProcessor()
        
        // 异步处理
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let processor = self.processor else { return }
            
            let success = processor.run(rootPath: path)
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processButton.isEnabled = true
                self.browseButton.isEnabled = true
                
                if success {
                    self.statusLabel.stringValue = "处理完成"
                    
                    // 获取数据
                    self.processedData = processor.getFinalData()
                    self.processedDataPlus = processor.getFinalDataPlus()
                    
                    // 获取统计信息
                    self.statistics = processor.getStatistics()
                    self.failures = processor.getFailureSummary()
                    
                    // 初始化筛选数据
                    self.filteredFailures = self.failures
                    
                    // 重置筛选和排序状态
                    self.filters.removeAll()
                    self.sortColumn = nil
                    
                    // 更新UI
                    self.tableView.reloadData()
                    
                    // 启用保存按钮
                    self.saveCSVButton.isEnabled = !self.processedData.isEmpty
                    self.saveCSVPlusButton.isEnabled = !self.processedDataPlus.isEmpty
                    self.exportJSONButton.isEnabled = true
                    
                    // 显示成功信息
                    let fileCount = self.statistics["total_files"] as? Int ?? 0
                    let paramCount = self.statistics["total_params"] as? Int ?? 0
                    let failureCount = self.statistics["failure_count"] as? Int ?? 0
                    
                    if failureCount > 0 {
                        self.showAlert(title: "处理完成", 
                                     message: """
                                     处理完成！
                                     文件数: \(fileCount)
                                     参数数: \(paramCount)
                                     发现 \(failureCount) 条失败记录
                                     """)
                    } else {
                        self.showAlert(title: "处理完成", 
                                     message: """
                                     处理完成！
                                     文件数: \(fileCount)
                                     参数数: \(paramCount)
                                     所有测试都通过 ✓
                                     """)
                    }
                    
                } else {
                    self.statusLabel.stringValue = "处理失败"
                    self.showAlert(title: "处理失败", message: "无法处理数据，请检查目录结构和文件权限")
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.beginSheetModal(for: window!, completionHandler: nil)
    }
    
    // MARK: - 静态方法
    static func createAndShow() -> HistoryWindowController {
        #if DEBUG
        print("🚀 HistoryWindowController: createAndShow 被调用")
        #endif
        let windowController = HistoryWindowController(window: NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        ))
        windowController.showWindow(nil)
        return windowController
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource
// 提示：双击文件路径列的内容，打开文件所在路径
extension HistoryWindowController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredFailures.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, row < filteredFailures.count else { return nil }
        
        let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
        var cell: NSTableCellView
        
        if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = reusedCell
        } else {
            // 创建新单元格
            cell = NSTableCellView()
            cell.identifier = cellIdentifier
            
            // 创建文本标签 - 支持多行
            let textField = NSTextField()
            textField.isEditable = false
            textField.isSelectable = true
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.font = NSFont.systemFont(ofSize: 11)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 0
            textField.cell?.wraps = true
            textField.cell?.isScrollable = false
            
            cell.addSubview(textField)
            cell.textField = textField
            
            // 布局约束 - 给文本更多空间
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
            ])
        }
        
        // 设置文本内容
        let cellValue = getCellValue(for: column.identifier.rawValue, row: row, useOriginalData: false)
        cell.textField?.stringValue = cellValue
        
        // 直接为单元格添加工具提示
        if column.identifier.rawValue == "失败用例" {
            let failure = filteredFailures[row]
            let components = failure.components(separatedBy: " | ")
            if components.count > 1 {
                let testCase = components[1]
                if testCase.count > 200 {
                    cell.toolTip = "完整内容：\n\(testCase)"
                }
            }
        } else if column.identifier.rawValue == "文件路径" {
            // 添加文件路径列的工具提示
            cell.toolTip = "双击打开文件所在路径"
        } else {
            cell.toolTip = nil
        }
        
        return cell
    }
    
    private func getCellValue(for column: String, row: Int, useOriginalData: Bool = false) -> String {
        // 根据参数选择使用原始数据还是过滤后的数据
        let targetArray = useOriginalData ? failures : filteredFailures
        guard row < targetArray.count else { return "" }
        
        let failure = targetArray[row]
        let components = failure.components(separatedBy: " | ")
        
        switch column {
        case "序号":
            return "\(row + 1)"
        case "测试时间":
            return components.count > 0 ? components[0] : "未知时间"
        case "失败用例":
            if components.count > 1 {
                return components[1]
            }
            return "无具体用例"
        case "文件路径":
            if components.count > 2 {
                let filePath = components[2]
                return filePath
                // 提取文件名
                //let url = URL(fileURLWithPath: filePath)
                //return url.lastPathComponent
            }
            return "未知文件"
        default:
            return ""
        }
    }
    
    // 关键：动态计算行高
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < filteredFailures.count else { return 40 }
        
        let failure = filteredFailures[row]
        let components = failure.components(separatedBy: " | ")
        
        // 只有失败用例需要特殊处理
        guard components.count > 1 else { return 40 }
        
        let testCase = components[1]
        
        // 如果文本很短，使用默认高度
        if testCase.count < 80 {
            return 40
        }
        
        // 计算文本所需高度
        let columnWidth: CGFloat = 500  // 失败用例列宽度
        let font = NSFont.systemFont(ofSize: 11)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        // 创建文本容器
        let textStorage = NSTextStorage(string: testCase)
        let textContainer = NSTextContainer(size: NSSize(width: columnWidth - 16, height: .greatestFiniteMagnitude))
        let layoutManager = NSLayoutManager()
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // 设置文本属性
        textStorage.addAttributes(attributes, range: NSRange(location: 0, length: testCase.count))
        
        // 强制布局
        layoutManager.glyphRange(for: textContainer)
        
        // 计算所需高度
        let textHeight = layoutManager.usedRect(for: textContainer).height
        let padding: CGFloat = 8  // 上下内边距
        
        // 返回计算高度，最小40，最大不超过200
        return max(40, min(textHeight + padding, 200))
    }
    
    // 实现双击打开文件所在路径
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 获取点击的列
        let clickedColumn = tableView.clickedColumn
        guard clickedColumn >= 0, clickedColumn < tableView.tableColumns.count else { return true }
        
        let column = tableView.tableColumns[clickedColumn]
        
        // 检查是否是文件路径列
        if column.identifier.rawValue == "文件路径" {
            // 获取文件路径
            let failure = filteredFailures[row]
            let components = failure.components(separatedBy: " | ")
            
            if components.count > 2 {
                let filePath = components[2]
                openFileLocation(filePath: filePath)
            }
        }
        
        return true
    }
    
    // 处理列标题点击事件
    func tableViewColumnDidClick(_ tableView: NSTableView, column: NSTableColumn) {
        #if DEBUG
        print("tableViewColumnDidClick被调用: \(column.identifier.rawValue)")
        #endif
        let columnName = column.identifier.rawValue
        // 使用当前事件
        if let event = NSApplication.shared.currentEvent {
            showColumnContextMenu(columnName: columnName, event: event)
        }
    }
    
    // 直接处理表格视图的鼠标点击事件
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        #if DEBUG
        print("鼠标点击事件: \(event)")
        #endif
        
        // 检查是否点击了表头
        if let tableView = self.tableView, let headerView = tableView.headerView {
            let point = tableView.convert(event.locationInWindow, from: nil)
            
            #if DEBUG
            print("鼠标位置: \(point)")
            print("表头边界: \(headerView.bounds)")
            #endif
            
            // 检查点击位置是否在表头内
            if headerView.frame.contains(point) {
                #if DEBUG
                print("点击了表头")
                #endif
                
                // 确定点击了哪一列
                let localPoint = headerView.convert(point, from: tableView)
                var clickedColumn: NSTableColumn?
                var currentX: CGFloat = 0
                
                for column in tableView.tableColumns {
                    currentX += column.width
                    if localPoint.x <= currentX {
                        clickedColumn = column
                        break
                    }
                }
                
                if let column = clickedColumn {
                    #if DEBUG
                    print("点击了列: \(column.identifier.rawValue)")
                    #endif
                    showColumnContextMenu(columnName: column.identifier.rawValue, event: event)
                }
            }
        }
    }
    
    // 打开文件所在路径
    private func openFileLocation(filePath: String) {
        let fileURL = URL(fileURLWithPath: filePath)
        let directoryURL = fileURL.deletingLastPathComponent()
        
        // 使用 Finder 打开目录
        NSWorkspace.shared.activateFileViewerSelecting([directoryURL])
    }
}
