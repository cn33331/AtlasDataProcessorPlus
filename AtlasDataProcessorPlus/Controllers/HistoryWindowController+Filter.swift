// HistoryWindowController+Filter.swift
// 负责筛选和排序相关的功能

import Cocoa

extension HistoryWindowController {
    
    // MARK: - 筛选和排序相关
    // 筛选和排序相关
    var sortColumn: String? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.sortColumn) as? String }
        set { objc_setAssociatedObject(self, &AssociatedKeys.sortColumn, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var sortAscending: Bool {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.sortAscending) as? Bool ?? true }
        set { objc_setAssociatedObject(self, &AssociatedKeys.sortAscending, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var filteredFailures: [String] {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.filteredFailures) as? [String] ?? [] }
        set { objc_setAssociatedObject(self, &AssociatedKeys.filteredFailures, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var filters: [String: Set<String>] {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.filters) as? [String: Set<String>] ?? [:] }
        set { objc_setAssociatedObject(self, &AssociatedKeys.filters, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // 为NSButton添加representedObject属性
    var buttonRepresentedObjects: [NSButton: Any] {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.buttonRepresentedObjects) as? [NSButton: Any] ?? [:] }
        set { objc_setAssociatedObject(self, &AssociatedKeys.buttonRepresentedObjects, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // 长按拖动多选相关
    var isMultiSelectMode: Bool {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.isMultiSelectMode) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.isMultiSelectMode, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var selectedCheckBoxes: Set<NSButton> {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.selectedCheckBoxes) as? Set<NSButton> ?? Set() }
        set { objc_setAssociatedObject(self, &AssociatedKeys.selectedCheckBoxes, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var currentFilterColumn: String? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.currentFilterColumn) as? String }
        set { objc_setAssociatedObject(self, &AssociatedKeys.currentFilterColumn, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var currentPopover: NSPopover? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.currentPopover) as? NSPopover }
        set { objc_setAssociatedObject(self, &AssociatedKeys.currentPopover, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var mouseDraggedMonitor: Any? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.mouseDraggedMonitor) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.mouseDraggedMonitor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var multiSelectMouseUpMonitor: Any? {
        get { return objc_getAssociatedObject(self, &AssociatedKeys.multiSelectMouseUpMonitor) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.multiSelectMouseUpMonitor, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // 显示列上下文菜单
    func showColumnContextMenu(columnName: String, event: NSEvent) {
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
    @objc func sortColumnAscending(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        sortColumn = columnName
        sortAscending = true
        applySortAndFilter()
    }
    
    // 降序排序
    @objc func sortColumnDescending(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        sortColumn = columnName
        sortAscending = false
        applySortAndFilter()
    }
    
    // 显示筛选菜单（使用NSPopover）
    @objc func showFilterMenu(_ sender: NSMenuItem) {
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
    func showFilterPopover(columnName: String, event: NSEvent?) {
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
    
    // 创建筛选视图
    func createFilterView(columnName: String, popover: NSPopover) -> NSView {
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
    @objc func selectAllInPopover(_ sender: NSButton) {
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
    @objc func toggleFilterValueInPopover(_ sender: NSButton) {
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
    @objc func cancelFilter(_ sender: NSButton) {
        if let popover = buttonRepresentedObjects[sender] as? NSPopover {
            popover.performClose(sender)
        }
    }
    
    // 确认筛选
    @objc func confirmFilter(_ sender: NSButton) {
        guard let data = buttonRepresentedObjects[sender] as? [String: Any],
              let popover = data["popover"] as? NSPopover else { return }
        
        // 应用筛选
        applySortAndFilter()
        
        // 关闭Popover
        popover.performClose(sender)
    }
    
    // 开始多选模式
    func startMultiSelectMode() {
        // 如果已经有监听器，先移除
        if let monitor = mouseDraggedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDraggedMonitor = nil
        }
        if let monitor = multiSelectMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            multiSelectMouseUpMonitor = nil
        }
        
        isMultiSelectMode = true
        selectedCheckBoxes.removeAll()
        
        // 开始监听鼠标事件
        mouseDraggedMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            guard let self = self else { return event }
            if self.isMultiSelectMode {
                self.handleMouseDragged(event)
            }
            return event
        }
        
        multiSelectMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            guard let self = self else { return event }
            if self.isMultiSelectMode {
                self.handleMouseUp(event)
            }
            return event
        }
    }
    
    // 处理鼠标拖动
    func handleMouseDragged(_ event: NSEvent) {
        if !isMultiSelectMode { return }
        
        // 获取鼠标位置
        let mouseLocation = event.locationInWindow
        
        // 碰撞检测
        detectCheckBoxes(at: mouseLocation)
        
        // 自动滚动
        handleAutoScroll(at: mouseLocation)
    }
    
    // 碰撞检测
    func detectCheckBoxes(at location: NSPoint) {
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
    func handleAutoScroll(at location: NSPoint) {
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
    func handleMouseUp(_ event: NSEvent) {
        isMultiSelectMode = false
        selectedCheckBoxes.removeAll()
        
        // 移除多选模式的事件监听器
        if let monitor = mouseDraggedMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDraggedMonitor = nil
        }
        if let monitor = multiSelectMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            multiSelectMouseUpMonitor = nil
        }
    }
    
    // 重置筛选
    @objc func resetFilter(_ sender: NSMenuItem) {
        guard let columnName = sender.representedObject as? String else { return }
        filters.removeValue(forKey: columnName)
        applySortAndFilter()
    }
    
    // 获取列的所有值
    func getColumnValues(columnName: String) -> Set<String> {
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
    func applySortAndFilter() {
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
}

// 关联对象键
private struct AssociatedKeys {
    static var sortColumn: UInt8 = 0
    static var sortAscending: UInt8 = 0
    static var filteredFailures: UInt8 = 0
    static var filters: UInt8 = 0
    static var buttonRepresentedObjects: UInt8 = 0
    static var isMultiSelectMode: UInt8 = 0
    static var selectedCheckBoxes: UInt8 = 0
    static var currentFilterColumn: UInt8 = 0
    static var currentPopover: UInt8 = 0
    static var mouseDraggedMonitor: UInt8 = 0
    static var multiSelectMouseUpMonitor: UInt8 = 0
}