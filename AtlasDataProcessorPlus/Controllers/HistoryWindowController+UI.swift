// HistoryWindowController+UI.swift
// 侧栏 + 工具栏 + 表格布局

import Cocoa

/// Y轴翻转视图，原点在左上角
private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// 支持 Cmd+C/V 的搜索框
private class CopyPasteSearchField: NSSearchField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let chars = event.charactersIgnoringModifiers else {
            return super.performKeyEquivalent(with: event)
        }
        switch chars {
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        default: return super.performKeyEquivalent(with: event)
        }
    }
}

extension HistoryWindowController {
    
    // MARK: - UI 设置
    func setupUI() {
        guard let window = window,
              let windowContentView = window.contentView else {
            debugLog("🔍 [HW] setupUI - window or contentView is nil, aborting")
            return
        }
        
        debugLog("🔍 [HW] setupUI - START, window: \(window.frame)")
        
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        windowContentView.addSubview(containerView)
        
        // 工具栏
        toolbarView = createToolbar()
        containerView.addSubview(toolbarView)
        debugLog("🔍 [HW] setupUI - toolbarView created, subviews: \(toolbarView.subviews.count)")
        
        // 分隔线
        let toolbarSeparator = NSBox()
        toolbarSeparator.boxType = .separator
        toolbarSeparator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toolbarSeparator)
        
        // 主体区域（侧栏 + 表格）
        let mainArea = NSView()
        mainArea.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(mainArea)
        
        // 侧栏
        sidebarView = createSidebar()
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(sidebarView)
        debugLog("🔍 [HW] setupUI - sidebarView created, subviews: \(sidebarView.subviews.count)")
        
        // 侧栏分隔线
        let sidebarSeparator = NSBox()
        sidebarSeparator.boxType = .separator
        sidebarSeparator.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(sidebarSeparator)
        
        // 表格
        let tableContainer = createTableViewContainer()
        tableContainer.translatesAutoresizingMaskIntoConstraints = false
        mainArea.addSubview(tableContainer)
        debugLog("🔍 [HW] setupUI - tableContainer created, subviews: \(tableContainer.subviews.count)")
        
        // 底部状态栏
        statusLabel = NSTextField(labelWithString: "准备就绪")
        statusLabel.alignment = .left
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
        
        // 底部状态栏分隔线
        let statusSeparator = NSBox()
        statusSeparator.boxType = .separator
        statusSeparator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusSeparator)
        
        window.title = "Atlas 历史数据处理"
        window.minSize = NSSize(width: 1000, height: 600)
        
        NSLayoutConstraint.activate([
            // containerView 填充 window.contentView
            containerView.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor),
            
            // 工具栏（偏移 52px 避开 fullSizeContentView 的标题栏区域）
            toolbarView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 52),
            toolbarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 36),
            
            toolbarSeparator.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            toolbarSeparator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            toolbarSeparator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            mainArea.topAnchor.constraint(equalTo: toolbarSeparator.bottomAnchor),
            mainArea.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            mainArea.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            mainArea.bottomAnchor.constraint(equalTo: statusSeparator.topAnchor),
            
            sidebarView.topAnchor.constraint(equalTo: mainArea.topAnchor),
            sidebarView.leadingAnchor.constraint(equalTo: mainArea.leadingAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),
            sidebarView.widthAnchor.constraint(equalToConstant: 200),
            
            sidebarSeparator.topAnchor.constraint(equalTo: mainArea.topAnchor),
            sidebarSeparator.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarSeparator.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),
            sidebarSeparator.widthAnchor.constraint(equalToConstant: 1),
            
            tableContainer.topAnchor.constraint(equalTo: mainArea.topAnchor),
            tableContainer.leadingAnchor.constraint(equalTo: sidebarSeparator.trailingAnchor),
            tableContainer.trailingAnchor.constraint(equalTo: mainArea.trailingAnchor),
            tableContainer.bottomAnchor.constraint(equalTo: mainArea.bottomAnchor),
            
            statusSeparator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusSeparator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusSeparator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -4),
            
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
            statusLabel.heightAnchor.constraint(equalToConstant: 16),
        ])
        
        debugLog("🔍 [HW] setupUI - constraints activated")
        debugLog("🔍 [HW] setupUI - containerView frame(before layout): \(containerView.frame)")
        debugLog("🔍 [HW] setupUI - window.contentView frame: \(windowContentView.frame)")
        
        // 强制布局
        containerView.layoutSubtreeIfNeeded()
        debugLog("🔍 [HW] setupUI - after layoutSubtree, containerView frame: \(containerView.frame)")
        debugLog("🔍 [HW] setupUI - toolbarView frame: \(toolbarView.frame)")
        if let sv = sidebarView { debugLog("🔍 [HW] setupUI - sidebarView frame: \(sv.frame)") }
        debugLog("🔍 [HW] setupUI - statusLabel frame: \(statusLabel?.frame ?? .zero)")
        debugLog("🔍 [HW] setupUI - tableContainer frame: \(tableContainer.frame)")
    }
    
    // MARK: - 工具栏
    func createToolbar() -> NSView {
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        
        // 分隔
        let sep1 = makeToolbarSeparator()
        stack.addArrangedSubview(sep1)
        
        // 排序按钮
        sortSlotButton = NSButton(title: "按 SLOT 排序", target: self, action: #selector(sortBySlot))
        sortSlotButton.bezelStyle = .rounded
        sortSlotButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(sortSlotButton)
        
        sortSNButton = NSButton(title: "按 SN 排序", target: self, action: #selector(sortBySN))
        sortSNButton.bezelStyle = .rounded
        sortSNButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(sortSNButton)
        
        sortTimeButton = NSButton(title: "按时间排序", target: self, action: #selector(sortByTime))
        sortTimeButton.bezelStyle = .rounded
        sortTimeButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(sortTimeButton)
        
        // 还原排序（按原始行号）
        resetSortButton = NSButton(title: "还原排序", target: self, action: #selector(resetSort))
        resetSortButton.bezelStyle = .rounded
        resetSortButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(resetSortButton)
        
        let sep2 = makeToolbarSeparator()
        stack.addArrangedSubview(sep2)
        
        // 重新解析
        reparseButton = NSButton(title: "⟳ 重新解析", target: self, action: #selector(processButtonClicked))
        reparseButton.bezelStyle = .rounded
        reparseButton.font = NSFont.systemFont(ofSize: 11)
        reparseButton.isEnabled = false
        stack.addArrangedSubview(reparseButton)
        
        // 已屏蔽fail项
        currentFailFilterButton = NSButton(title: "已屏蔽fail项", target: self, action: #selector(showCurrentFailFilter(_:)))
        currentFailFilterButton.bezelStyle = .rounded
        currentFailFilterButton.font = NSFont.systemFont(ofSize: 11)
        currentFailFilterButton.isEnabled = false
        stack.addArrangedSubview(currentFailFilterButton)
        
        // 导出
        exportCSVButton = NSButton(title: "导出 CSV", target: self, action: #selector(saveCSVButtonClicked))
        exportCSVButton.bezelStyle = .rounded
        exportCSVButton.font = NSFont.systemFont(ofSize: 11)
        exportCSVButton.isEnabled = false
        stack.addArrangedSubview(exportCSVButton)
        
        // 弹性空间
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        
        // 搜索框（使用 CopyPasteSearchField 支持 Cmd+C/V）
        searchField = CopyPasteSearchField()
        searchField.placeholderString = "搜索 SN / S_BUILD / 测试项"
        searchField.font = NSFont.systemFont(ofSize: 11)
        searchField.target = self
        searchField.action = #selector(searchTextChanged(_:))
        searchField.sendsWholeSearchString = false
        searchField.widthAnchor.constraint(equalToConstant: 200).isActive = true
        stack.addArrangedSubview(searchField)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -4),
        ])
        
        return bar
    }
    
    private func makeToolbarSeparator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return sep
    }
    
    // MARK: - 侧栏
    func createSidebar() -> NSView {
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(scrollView)
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setHuggingPriority(.required, for: .vertical)
        
        // 用 FlippedView 包裹 stack，确保内容从顶部开始排列
        let docView = FlippedView()
        docView.translatesAutoresizingMaskIntoConstraints = false
        docView.addSubview(stack)
        scrollView.documentView = docView
        
        // 数据目录
        let folderSection = createSidebarSection(title: "数据目录")
        stack.addArrangedSubview(folderSection)
        
        pathTextField = NSTextField()
        pathTextField.placeholderString = "选择目录..."
        pathTextField.font = NSFont.systemFont(ofSize: 10)
        pathTextField.lineBreakMode = .byTruncatingHead
        pathTextField.stringValue = "/Users/gdlocal/Library/Logs/Atlas/unit-archive"
        pathTextField.translatesAutoresizingMaskIntoConstraints = false
        pathTextField.widthAnchor.constraint(equalToConstant: 184).isActive = true
        stack.addArrangedSubview(pathTextField)
        
        browseButton = NSButton(title: "选择文件夹...", target: self, action: #selector(browseButtonClicked))
        browseButton.bezelStyle = .rounded
        browseButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(browseButton)
        
        processButton = NSButton(title: "开始处理", target: self, action: #selector(processButtonClicked))
        processButton.bezelStyle = .rounded
        processButton.keyEquivalent = "\r"
        processButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        stack.addArrangedSubview(processButton)
        
        // 清除过滤
        let clearBtn = NSButton(title: "清除所有过滤", target: self, action: #selector(clearAllFilters))
        clearBtn.bezelStyle = .rounded
        clearBtn.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(clearBtn)
        
        // 状态过滤
        let statusSection = createSidebarSection(title: "状态过滤")
        stack.addArrangedSubview(statusSection)
        
        let statusFilterStack = NSStackView()
        statusFilterStack.orientation = .horizontal
        statusFilterStack.spacing = 4
        statusFilterStack.distribution = .fillEqually
        statusFilterStack.widthAnchor.constraint(equalToConstant: 184).isActive = true
        stack.addArrangedSubview(statusFilterStack)
        
        allFilterButton = NSButton(title: "全部", target: self, action: #selector(setStatusFilter(_:)))
        allFilterButton.bezelStyle = .rounded
        allFilterButton.font = NSFont.systemFont(ofSize: 11)
        allFilterButton.tag = 0
        highlightButton(allFilterButton, active: true)
        statusFilterStack.addArrangedSubview(allFilterButton)
        
        passFilterButton = NSButton(title: "仅 PASS", target: self, action: #selector(setStatusFilter(_:)))
        passFilterButton.bezelStyle = .rounded
        passFilterButton.font = NSFont.systemFont(ofSize: 11)
        passFilterButton.tag = 1
        statusFilterStack.addArrangedSubview(passFilterButton)
        
        failFilterButton = NSButton(title: "仅 FAIL", target: self, action: #selector(setStatusFilter(_:)))
        failFilterButton.bezelStyle = .rounded
        failFilterButton.font = NSFont.systemFont(ofSize: 11)
        failFilterButton.tag = 2
        statusFilterStack.addArrangedSubview(failFilterButton)
        
        // 状态统计行
        statusSummaryLabel = NSTextField(labelWithString: "")
        statusSummaryLabel.font = NSFont.systemFont(ofSize: 10)
        statusSummaryLabel.textColor = .secondaryLabelColor
        statusSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(statusSummaryLabel)
        
        // 日期范围
        let dateSection = createSidebarSection(title: "日期范围")
        stack.addArrangedSubview(dateSection)
        
        // 日期范围 - 紧凑单行布局
        let dateRowStack = NSStackView()
        dateRowStack.orientation = .horizontal
        dateRowStack.spacing = 2
        dateRowStack.alignment = .centerY
        dateRowStack.translatesAutoresizingMaskIntoConstraints = false
        dateRowStack.widthAnchor.constraint(equalToConstant: 184).isActive = true
        stack.addArrangedSubview(dateRowStack)
        
        let fromLabel = NSTextField(labelWithString: "从")
        fromLabel.font = NSFont.systemFont(ofSize: 10)
        fromLabel.textColor = .secondaryLabelColor
        dateRowStack.addArrangedSubview(fromLabel)
        
        dateFromPicker = NSDatePicker()
        dateFromPicker.datePickerStyle = .textField
        dateFromPicker.datePickerElements = [.yearMonthDay, .hourMinute]
        dateFromPicker.font = NSFont.systemFont(ofSize: 10)
        dateFromPicker.target = self
        dateFromPicker.action = #selector(dateFilterChanged(_:))
        dateRowStack.addArrangedSubview(dateFromPicker)
        
        let toLabel = NSTextField(labelWithString: "至")
        toLabel.font = NSFont.systemFont(ofSize: 10)
        toLabel.textColor = .secondaryLabelColor
        dateRowStack.addArrangedSubview(toLabel)
        
        dateToPicker = NSDatePicker()
        dateToPicker.datePickerStyle = .textField
        dateToPicker.datePickerElements = [.yearMonthDay, .hourMinute]
        dateToPicker.font = NSFont.systemFont(ofSize: 10)
        dateToPicker.target = self
        dateToPicker.action = #selector(dateFilterChanged(_:))
        dateRowStack.addArrangedSubview(dateToPicker)
        
        // 快捷日期按钮
        let dateQuickStack = NSStackView()
        dateQuickStack.orientation = .horizontal
        dateQuickStack.spacing = 3
        dateQuickStack.distribution = .fillEqually
        dateQuickStack.translatesAutoresizingMaskIntoConstraints = false
        dateQuickStack.widthAnchor.constraint(equalToConstant: 184).isActive = true
        stack.addArrangedSubview(dateQuickStack)
        
        let quickPresets: [(String, Selector)] = [
            ("今天", #selector(dateQuickToday)),
            ("近3天", #selector(dateQuick3Days)),
            ("近7天", #selector(dateQuick7Days)),
            ("全部", #selector(dateQuickAll)),
        ]
        for (title, action) in quickPresets {
            let btn = NSButton(title: title, target: self, action: action)
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 9)
            btn.controlSize = .mini
            dateQuickStack.addArrangedSubview(btn)
        }
        
        // 快捷时间按钮（分钟级）
        let timeQuickStack = NSStackView()
        timeQuickStack.orientation = .horizontal
        timeQuickStack.spacing = 3
        timeQuickStack.distribution = .fillEqually
        timeQuickStack.translatesAutoresizingMaskIntoConstraints = false
        timeQuickStack.widthAnchor.constraint(equalToConstant: 184).isActive = true
        stack.addArrangedSubview(timeQuickStack)
        
        let timePresets: [(String, Selector)] = [
            ("近1小时", #selector(dateQuick1Hour)),
            ("近6小时", #selector(dateQuick6Hours)),
            ("近12小时", #selector(dateQuick12Hours)),
        ]
        for (title, action) in timePresets {
            let btn = NSButton(title: title, target: self, action: action)
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 9)
            btn.controlSize = .mini
            timeQuickStack.addArrangedSubview(btn)
        }
        
        // SLOT 统计
        let slotSection = createSidebarSection(title: "SLOT 统计")
        stack.addArrangedSubview(slotSection)
        
        slotStatsView = NSView()
        slotStatsView.translatesAutoresizingMaskIntoConstraints = false
        slotStatsView.widthAnchor.constraint(equalToConstant: 184).isActive = true
        slotStatsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        stack.addArrangedSubview(slotStatsView)
        
        // S_BUILD 统计
        let sBuildSection = createSidebarSection(title: "S_BUILD 统计")
        stack.addArrangedSubview(sBuildSection)
        
        sBuildStatsView = NSView()
        sBuildStatsView.translatesAutoresizingMaskIntoConstraints = false
        sBuildStatsView.widthAnchor.constraint(equalToConstant: 184).isActive = true
        sBuildStatsView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        stack.addArrangedSubview(sBuildStatsView)
        
        // 屏蔽管理
        let blockSection = createSidebarSection(title: "屏蔽管理")
        stack.addArrangedSubview(blockSection)
        
        defaultBlockButton = NSButton(title: "默认屏蔽项", target: self, action: #selector(showBlockFailDialog(_:)))
        defaultBlockButton.bezelStyle = .rounded
        defaultBlockButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(defaultBlockButton)
        
        // 表格配置
        let tableConfigButton = NSButton(title: "表格配置", target: self, action: #selector(showTableConfigDialog(_:)))
        tableConfigButton.bezelStyle = .rounded
        tableConfigButton.font = NSFont.systemFont(ofSize: 11)
        stack.addArrangedSubview(tableConfigButton)
        
        // 约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -8),
            
            // docView 作为 documentView，靠顶部对齐
            docView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            docView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            docView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // stack 填满 docView（FlippedView 原点在左上角）
            stack.topAnchor.constraint(equalTo: docView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: docView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: docView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: docView.bottomAnchor),
        ])
        
        return sidebar
    }
    
    private func createSidebarSection(title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }
    
    // MARK: - 表格容器
    func createTableViewContainer() -> NSView {
        let container = NSView()
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)
        
        tableView = ContextMenuTableView()
        (tableView as! ContextMenuTableView).contextMenuHandler = { [weak self] row in
            return self?.buildContextMenu(row: row)
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 28
        tableView.allowsColumnSelection = true
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .regular
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        let columns: [(String, CGFloat)] = [
            ("#", 20),
            ("测试时间", 140),
            ("SN", 140),
            ("SlotID", 20),
            ("S_BUILD", 100),
            ("Status", 40),
            ("测试项", 220),
            ("测试值", 120),
            ("上限值", 100),
            ("下限值", 100),
        ]
        
        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = width
            column.minWidth = 30
            tableView.addTableColumn(column)
        }
        
        scrollView.documentView = tableView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        return container
    }
    
    // MARK: - 侧栏切换
    @objc func toggleSidebar() {
        sidebarVisible.toggle()
        sidebarView.isHidden = !sidebarVisible
        
        // 调整侧栏宽度约束
        if let mainArea = sidebarView.superview {
            for constraint in mainArea.constraints {
                if constraint.firstItem as? NSView == sidebarView && constraint.firstAttribute == .width {
                    constraint.constant = sidebarVisible ? 200 : 0
                    break
                }
            }
        }
    }
    
    // MARK: - 按钮高亮
    func highlightButton(_ button: NSButton, active: Bool) {
        if active {
            button.contentTintColor = .white
            button.bezelColor = .controlAccentColor
        } else {
            button.contentTintColor = nil
            button.bezelColor = nil
        }
    }
    
    // MARK: - 更新 SLOT 统计（排除式多选）
    func updateSlotStats() {
        updateStatCards(
            in: slotStatsView,
            heightConstraint: &slotStatsHeightConstraint,
            records: allRecords,
            keyPath: \.slotID,
            titlePrefix: "SLOT",
            excludedSet: excludedSlots,
            onToggle: #selector(slotCardToggled(_:))
        )
    }
    
    // MARK: - 更新 S_BUILD 统计（排除式多选）
    func updateSBuildStats() {
        updateStatCards(
            in: sBuildStatsView,
            heightConstraint: &sBuildStatsHeightConstraint,
            records: allRecords,
            keyPath: \.sBuild,
            titlePrefix: "B",
            excludedSet: excludedSBuilds,
            onToggle: #selector(sBuildCardToggled(_:))
        )
    }
    
    /// 通用的排除式多选统计卡片
    private func updateStatCards(
        in container: NSView,
        heightConstraint: inout NSLayoutConstraint?,
        records: [TestRecord],
        keyPath: KeyPath<TestRecord, String>,
        titlePrefix: String,
        excludedSet: Set<String>,
        onToggle: Selector
    ) {
        container.subviews.forEach { $0.removeFromSuperview() }
        
        var statData: [String: (pass: Int, fail: Int)] = [:]
        for record in records {
            let key = record[keyPath: keyPath]
            let value = key.isEmpty ? "?" : key
            var data = statData[value] ?? (0, 0)
            if record.status == "PASS" {
                data.pass += 1
            } else if record.status == "FAIL" {
                data.fail += 1
            }
            statData[value] = data
        }
        
        let sortedKeys = statData.keys.sorted { a, b in
            Int(a) ?? 999 < Int(b) ?? 999
        }
        
        guard !sortedKeys.isEmpty else {
            let label = NSTextField(labelWithString: "无数据")
            label.font = NSFont.systemFont(ofSize: 10)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            updateStatHeight(container: container, constraint: &heightConstraint, rows: 1)
            return
        }
        
        let availableWidth = container.bounds.width > 0 ? container.bounds.width : 184
        let cardWidth: CGFloat = 88
        let cardHeight: CGFloat = 36
        let gap: CGFloat = 6
        let cols = max(1, Int((availableWidth + gap) / (cardWidth + gap)))
        
        for (i, key) in sortedKeys.enumerated() {
            let data = statData[key]!
            let col = i % cols
            let row = i / cols
            let isChecked = !excludedSet.contains(key)  // 默认勾选，排除则取消
            
            let card = NSView()
            card.wantsLayer = true
            card.layer?.backgroundColor = isChecked
                ? NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
                : NSColor.controlBackgroundColor.cgColor
            card.layer?.borderColor = isChecked
                ? NSColor.controlAccentColor.cgColor
                : NSColor.separatorColor.cgColor
            card.layer?.borderWidth = isChecked ? 1.5 : 0.5
            card.layer?.cornerRadius = 4
            card.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(card)
            
            NSLayoutConstraint.activate([
                card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: CGFloat(col) * (cardWidth + gap)),
                card.topAnchor.constraint(equalTo: container.topAnchor, constant: CGFloat(row) * (cardHeight + gap)),
                card.widthAnchor.constraint(equalToConstant: cardWidth),
                card.heightAnchor.constraint(equalToConstant: cardHeight),
            ])
            
            // Checkmark 标记（右上角）
            if isChecked {
                let checkmark = NSTextField(labelWithString: "✓")
                checkmark.font = NSFont.systemFont(ofSize: 10, weight: .bold)
                checkmark.textColor = .controlAccentColor
                checkmark.frame = NSRect(x: cardWidth - 18, y: cardHeight - 16, width: 14, height: 12)
                checkmark.alignment = .right
                card.addSubview(checkmark)
            }
            
            let nameLabel = NSTextField(labelWithString: "\(titlePrefix) \(key)")
            nameLabel.font = NSFont.systemFont(ofSize: 9)
            nameLabel.textColor = isChecked ? .controlAccentColor : .secondaryLabelColor
            nameLabel.frame = NSRect(x: 4, y: cardHeight - 16, width: cardWidth - 24, height: 12)
            card.addSubview(nameLabel)
            
            let statsLabel = NSTextField(labelWithString: "P:\(data.pass)  F:\(data.fail)")
            statsLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            statsLabel.frame = NSRect(x: 4, y: 2, width: cardWidth - 8, height: 14)
            card.addSubview(statsLabel)
            
            // 颜色分段条
            let total = data.pass + data.fail
            if total > 0 {
                let passRatio = CGFloat(data.pass) / CGFloat(total)
                let colorBar = NSView()
                colorBar.wantsLayer = true
                colorBar.layer?.backgroundColor = NSColor.systemGreen.cgColor
                colorBar.frame = NSRect(x: 0, y: 0, width: cardWidth * passRatio, height: 2)
                card.addSubview(colorBar)
                
                if data.fail > 0 {
                    let failBar = NSView()
                    failBar.wantsLayer = true
                    failBar.layer?.backgroundColor = NSColor.systemRed.cgColor
                    failBar.frame = NSRect(x: cardWidth * passRatio, y: 0, width: cardWidth * (1 - passRatio), height: 2)
                    card.addSubview(failBar)
                }
            }
            
            let click = NSClickGestureRecognizer(target: self, action: onToggle)
            card.addGestureRecognizer(click)
        }
        
        let totalRows = (sortedKeys.count + cols - 1) / cols
        updateStatHeight(container: container, constraint: &heightConstraint, rows: totalRows)
    }
    
    // MARK: - 统计卡片点击（切换排除状态）
    @objc func slotCardToggled(_ gesture: NSClickGestureRecognizer) {
        guard let card = gesture.view else { return }
        let slot = extractStatKey(from: card, prefix: "SLOT ")
        if excludedSlots.contains(slot) {
            excludedSlots.remove(slot)
        } else {
            excludedSlots.insert(slot)
        }
        applyFilters()
        updateSlotStats()
        updateSBuildStats()
    }
    
    @objc func sBuildCardToggled(_ gesture: NSClickGestureRecognizer) {
        guard let card = gesture.view else { return }
        let sBuild = extractStatKey(from: card, prefix: "B ")
        if excludedSBuilds.contains(sBuild) {
            excludedSBuilds.remove(sBuild)
        } else {
            excludedSBuilds.insert(sBuild)
        }
        applyFilters()
        updateSlotStats()
        updateSBuildStats()
    }
    
    /// 从卡片子视图中提取统计键值（如 "SLOT 1" → "1"）
    private func extractStatKey(from card: NSView, prefix: String) -> String {
        for subview in card.subviews {
            if let label = subview as? NSTextField, label.stringValue.hasPrefix(prefix) {
                return String(label.stringValue.dropFirst(prefix.count))
            }
        }
        return ""
    }
    
    private func updateStatHeight(container: NSView, constraint: inout NSLayoutConstraint?, rows: Int) {
        let cardHeight: CGFloat = 36
        let gap: CGFloat = 6
        let newHeight = max(40, CGFloat(rows) * (cardHeight + gap))
        constraint?.isActive = false
        constraint = container.heightAnchor.constraint(equalToConstant: newHeight)
        constraint?.isActive = true
    }
}