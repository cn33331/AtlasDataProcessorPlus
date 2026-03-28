// HistoryWindowController+Table.swift
// 负责表格视图相关的功能

import Cocoa

extension HistoryWindowController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        var count = 0
        for (index, group) in groupedFailures.enumerated() {
            count += 1 // 分组标题行
            if expandedGroups.contains(index) {
                count += group.items.count // 展开时加上分组内的行数
            }
        }
        return count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        
        // 计算当前行对应的分组和位置
        let (groupIndex, isHeader, itemIndex) = getGroupInfo(forRow: row)
        
        if isHeader {
            // 显示分组标题
            return createHeaderCell(for: column, groupIndex: groupIndex)
        } else {
            // 显示分组内容
            return createContentCell(for: column, groupIndex: groupIndex, itemIndex: itemIndex)
        }
    }
    
    // 计算行对应的分组信息
    func getGroupInfo(forRow row: Int) -> (groupIndex: Int, isHeader: Bool, itemIndex: Int) {
        var currentRow = 0
        
        for (groupIndex, group) in groupedFailures.enumerated() {
            // 检查是否是分组标题行
            if currentRow == row {
                return (groupIndex, true, -1)
            }
            currentRow += 1
            
            // 如果分组是展开的，检查是否是分组内的行
            if expandedGroups.contains(groupIndex) {
                for itemIndex in 0..<group.items.count {
                    if currentRow == row {
                        return (groupIndex, false, itemIndex)
                    }
                    currentRow += 1
                }
            }
        }
        
        return (-1, false, -1)
    }
    
    // 创建分组标题单元格
    func createHeaderCell(for column: NSTableColumn, groupIndex: Int) -> NSTableCellView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("HeaderCell")
        var cell: NSTableCellView
        
        if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = reusedCell
        } else {
            // 创建新单元格
            cell = NSTableCellView()
            cell.identifier = cellIdentifier
            
            // 创建文本标签
            let textField = NSTextField()
            textField.isEditable = false
            textField.isSelectable = false
            textField.isBezeled = false
            textField.drawsBackground = true
            textField.backgroundColor = NSColor.lightGray.withAlphaComponent(0.1)
            textField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            cell.addSubview(textField)
            cell.textField = textField
            
            // 布局约束
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
            ])
        }
        
        // 设置文本内容
        let group = groupedFailures[groupIndex]
        let isExpanded = expandedGroups.contains(groupIndex)
        let expandSymbol = isExpanded ? "▼" : "▶"
        
        if column.identifier.rawValue == "文件路径" {
            cell.textField?.stringValue = "\(expandSymbol) \(group.filePath) (\(group.items.count) 条记录)"
        } else if !group.items.isEmpty {
            // 显示组中的第一个内容
            let firstFailure = group.items[0]
            let components = firstFailure.components(separatedBy: " | ")
            
            switch column.identifier.rawValue {
            case "序号":
                cell.textField?.stringValue = "\(groupIndex + 1)"
            case "测试时间":
                cell.textField?.stringValue = components.count > 0 ? components[0] : "未知时间"
            case "失败用例":
                cell.textField?.stringValue = components.count > 1 ? components[1] : "无具体用例"
            case "Upper Limit":
                cell.textField?.stringValue = components.count > 3 ? components[3] : ""
            case "Lower Limit":
                cell.textField?.stringValue = components.count > 4 ? components[4] : ""
            case "Value":
                cell.textField?.stringValue = components.count > 5 ? components[5] : ""
            default:
                cell.textField?.stringValue = ""
            }
        } else {
            cell.textField?.stringValue = ""
        }
        
        return cell
    }
    
    // 创建内容单元格
    func createContentCell(for column: NSTableColumn, groupIndex: Int, itemIndex: Int) -> NSTableCellView {
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
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 24), // 缩进
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4)
            ])
        }
        
        // 设置文本内容
        let group = groupedFailures[groupIndex]
        let failure = group.items[itemIndex]
        let components = failure.components(separatedBy: " | ")
        
        switch column.identifier.rawValue {
        case "序号":
            cell.textField?.stringValue = "\(itemIndex + 1)"
        case "测试时间":
            cell.textField?.stringValue = components.count > 0 ? components[0] : "未知时间"
        case "失败用例":
            cell.textField?.stringValue = components.count > 1 ? components[1] : "无具体用例"
        case "文件路径":
            cell.textField?.stringValue = components.count > 2 ? components[2] : ""
        case "Upper Limit":
            cell.textField?.stringValue = components.count > 3 ? components[3] : ""
        case "Lower Limit":
            cell.textField?.stringValue = components.count > 4 ? components[4] : ""
        case "Value":
            cell.textField?.stringValue = components.count > 5 ? components[5] : ""
        default:
            cell.textField?.stringValue = ""
        }
        
        // 添加工具提示
        if column.identifier.rawValue == "失败用例" {
            let components = failure.components(separatedBy: " | ")
            if components.count > 1 {
                let testCase = components[1]
                if testCase.count > 200 {
                    cell.toolTip = "完整内容：\n\(testCase)"
                }
            }
        }
        
        return cell
    }
    
    func getCellValue(for column: String, row: Int, useOriginalData: Bool = false) -> String {
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
            }
            return "未知文件"
        case "Upper Limit":
            return components.count > 3 ? components[3] : ""
        case "Lower Limit":
            return components.count > 4 ? components[4] : ""
        case "Value":
            return components.count > 5 ? components[5] : ""
        default:
            return ""
        }
    }
    
    // 处理表格视图的行选择事件
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 允许选中所有行，包括标题行
        return true
    }
    
    // 关键：动态计算行高
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        // 计算当前行对应的分组和位置
        let (groupIndex, isHeader, itemIndex) = getGroupInfo(forRow: row)
        
        if isHeader {
            // 分组标题行固定高度
            return 30
        } else if groupIndex >= 0 && itemIndex >= 0 {
            // 内容行，根据内容计算高度
            let group = groupedFailures[groupIndex]
            let failure = group.items[itemIndex]
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
            let textContainer = NSTextContainer(size: NSSize(width: columnWidth - 32, height: .greatestFiniteMagnitude)) // 减去缩进
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
        
        return 40
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
    
    // 右键菜单
    func tableView(_ tableView: NSTableView, menuFor event: NSEvent) -> NSMenu? {
        print("🍽️ 菜单请求事件触发")
        print("事件位置: \(event.locationInWindow)")
        print("事件类型: \(event.type)")
        print("点击次数: \(event.clickCount)")
        
        let point = tableView.convert(event.locationInWindow, from: nil)
        let row = tableView.row(at: point)
        
        print("转换后的点: \(point)")
        print("点击的行: \(row)")
        print("表格视图边界: \(tableView.bounds)")
        
        if row == -1 {
            print("❌ 没有点击到任何行")
            return nil
        }
        
        // 选中点击的行
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        
        print("✅ 选中行: \(row)")
        
        // 计算当前行对应的分组和位置
        let (groupIndex, isHeader, itemIndex) = getGroupInfo(forRow: row)
        
        print("分组信息: groupIndex=\(groupIndex), isHeader=\(isHeader), itemIndex=\(itemIndex)")
        
        let menu = NSMenu(title: "右键菜单")
        
        // 为所有行提供基本菜单选项
        if groupIndex >= 0 {
            if isHeader {
                print("📁 点击了分组标题行")
                // 分组标题的菜单
                let group = groupedFailures[groupIndex]
                
                // 打开文件路径选项
                let openPathItem = NSMenuItem(title: "打开文件路径", action: #selector(openFilePath(_:)), keyEquivalent: "")
                openPathItem.representedObject = ["filePath": group.filePath]
                openPathItem.target = self
                menu.addItem(openPathItem)
                
                // 显示/隐藏详情选项
                let toggleDetailsItem = NSMenuItem(title: expandedGroups.contains(groupIndex) ? "隐藏详情" : "显示详情", action: #selector(toggleGroupDetails(_:)), keyEquivalent: "")
                toggleDetailsItem.representedObject = ["groupIndex": groupIndex]
                toggleDetailsItem.target = self
                menu.addItem(toggleDetailsItem)
                
                // 删除本组失败记录选项
                let deleteGroupItem = NSMenuItem(title: "删除本组失败记录", action: #selector(deleteGroup(_:)), keyEquivalent: "")
                deleteGroupItem.representedObject = ["groupIndex": groupIndex]
                deleteGroupItem.target = self
                menu.addItem(deleteGroupItem)
            } else if itemIndex >= 0 {
                print("📋 点击了内容行")
                // 内容行的菜单
                let group = groupedFailures[groupIndex]
                let failure = group.items[itemIndex]
                let components = failure.components(separatedBy: " | ")
                let filePath = components.count > 2 ? components[2] : "未知文件"
                
                // 打开文件路径选项
                let openPathItem = NSMenuItem(title: "打开文件路径", action: #selector(openFilePath(_:)), keyEquivalent: "")
                openPathItem.representedObject = ["filePath": filePath]
                openPathItem.target = self
                menu.addItem(openPathItem)
                
                // 删除本条失败记录选项
                let deleteItemItem = NSMenuItem(title: "删除本条失败记录", action: #selector(deleteItem(_:)), keyEquivalent: "")
                deleteItemItem.representedObject = ["groupIndex": groupIndex, "itemIndex": itemIndex]
                deleteItemItem.target = self
                menu.addItem(deleteItemItem)
                
                // 删除全局相同失败用例的记录选项
                let deleteGlobalItem = NSMenuItem(title: "删除全局相同失败用例的记录", action: #selector(deleteGlobalSameFailure(_:)), keyEquivalent: "")
                deleteGlobalItem.representedObject = ["groupIndex": groupIndex, "itemIndex": itemIndex]
                deleteGlobalItem.target = self
                menu.addItem(deleteGlobalItem)
            }
        }
        
        // 如果没有添加任何菜单项，返回一个默认菜单
        if menu.numberOfItems == 0 {
            print("⚠️ 没有添加任何菜单项，使用默认菜单")
            let defaultItem = NSMenuItem(title: "无可用操作", action: nil, keyEquivalent: "")
            defaultItem.isEnabled = false
            menu.addItem(defaultItem)
        }
        
        print("🍽️ 菜单创建完成，包含 \(menu.numberOfItems) 个项目")
        for (index, item) in menu.items.enumerated() {
            print("  菜单项 \(index + 1): \(item.title)")
            print("  菜单项动作: \(String(describing: item.action))")
            print("  菜单项目标: \(String(describing: item.target))")
        }
        
        return menu
    }
}