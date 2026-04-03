// HistoryWindowController+UI.swift
// 负责UI设置和界面创建

import Cocoa

extension HistoryWindowController {
    
    // MARK: - UI 设置
    func setupUI() {
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
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            
            // 表格视图最小高度
            tableContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        #if DEBUG
        print("✅ HistoryWindowController: UI 设置完成")
        print("📊 UI 组件数量: \(containerView.subviews.count)")
        #endif
    }
    
    // MARK: - 创建控制面板
    func createControlPanel() -> NSView {
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
    func createTableView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 标题和按钮容器
        let headerStackView = NSStackView()
        headerStackView.orientation = .horizontal
        headerStackView.spacing = 10
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerStackView)
        
        // 标题
        let tableTitle = NSTextField(labelWithString: "失败记录")
        tableTitle.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tableTitle.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(tableTitle)
        
        // 展开所有按钮
        let expandAllButton = NSButton(title: "展开所有", target: self, action: #selector(expandAllGroups))
        expandAllButton.bezelStyle = .rounded
        expandAllButton.font = NSFont.systemFont(ofSize: 12)
        expandAllButton.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(expandAllButton)
        
        // 折叠所有按钮
        let collapseAllButton = NSButton(title: "折叠所有", target: self, action: #selector(collapseAllGroups))
        collapseAllButton.bezelStyle = .rounded
        collapseAllButton.font = NSFont.systemFont(ofSize: 12)
        collapseAllButton.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(collapseAllButton)
        
        // 当前fail筛选按钮
        let currentFailFilterButton = NSButton(title: "当前fail筛选", target: self, action: #selector(showCurrentFailFilter(_:)))
        currentFailFilterButton.bezelStyle = .rounded
        currentFailFilterButton.font = NSFont.systemFont(ofSize: 12)
        currentFailFilterButton.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(currentFailFilterButton)
        
        // 表格配置按钮
        let tableConfigButton = NSButton(title: "表格配置", target: self, action: #selector(showTableConfigDialog(_:)))
        tableConfigButton.bezelStyle = .rounded
        tableConfigButton.font = NSFont.systemFont(ofSize: 12)
        tableConfigButton.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(tableConfigButton)
        
        // 默认屏蔽项按钮
        let blockFailButton = NSButton(title: "默认屏蔽项", target: self, action: #selector(showBlockFailDialog(_:)))
        blockFailButton.bezelStyle = .rounded
        blockFailButton.font = NSFont.systemFont(ofSize: 12)
        blockFailButton.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.addArrangedSubview(blockFailButton)
        
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
        // 确保表格的delegate/dataSource已设置（否则menuForRow不会被调用）
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 40
        tableView.allowsColumnSelection = true
        // 不设置固定菜单，使用menuFor方法动态生成菜单
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .regular
        
        // 使用自定义表头视图
        let customHeaderView = CustomTableHeaderView(frame: NSRect(x: 0, y: 0, width: 1000, height: 30))
        customHeaderView.tableView = tableView
        tableView.headerView = customHeaderView
        
        #if DEBUG
        print("表格视图委托设置: \(tableView.delegate != nil)")
        print("表格视图数据源设置: \(tableView.dataSource != nil)")
        print("使用自定义表头视图: \(tableView.headerView is CustomTableHeaderView)")
        #endif
        
        // 设置列
        let columns = [
            ("序号", 40),
            ("测试时间", 150),
            ("失败用例", 300),
            ("Upper Limit", 80),
            ("Lower Limit", 80),
            ("Value", 120),
            ("文件路径", 200),
            ("SN", 150),
            ("通道号", 80)
        ]
        
        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = CGFloat(width)
            tableView.addTableColumn(column)
        }
        
        scrollView.documentView = tableView
        
        NSLayoutConstraint.activate([
            headerStackView.topAnchor.constraint(equalTo: container.topAnchor),
            headerStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
        
        return container
    }
    
    // MARK: - 创建操作按钮
    func createActionButtons() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        // 保存 Fail 标题行按钮
        saveFailHeadersButton = NSButton(title: "保存 Fail 标题行", target: self, action: #selector(saveFailHeadersButtonClicked))
        saveFailHeadersButton.bezelStyle = .rounded
        saveFailHeadersButton.isEnabled = false
        stack.addArrangedSubview(saveFailHeadersButton)
        
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
}
