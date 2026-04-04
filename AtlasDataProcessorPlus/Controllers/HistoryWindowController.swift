// HistoryWindowController.swift
// Atlas 历史数据处理窗口控制器
// 主文件 - 只包含核心类和属性定义
// 功能实现分布在以下扩展文件中：
// - HistoryWindowController+UI.swift: UI设置和界面创建
// - HistoryWindowController+Table.swift: 表格视图相关功能
// - HistoryWindowController+Filter.swift: 筛选和排序功能
// - HistoryWindowController+Actions.swift: 按钮动作和业务逻辑

import Cocoa

// MARK: - 自定义表头视图
// 用于处理表头点击事件
class CustomTableHeaderView: NSTableHeaderView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

// MARK: - 可长按复选框
// 支持长按手势实现快速多选功能
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

// MARK: - 分组失败记录结构
// 用于折叠/展开功能的数据结构
struct GroupedFailure {
    let filePath: String
    var items: [String] // 存储完整的失败记录字符串
}

// MARK: - 历史数据处理窗口控制器
class HistoryWindowController: NSWindowController {
    
    // MARK: - UI 组件
    // 控制面板
    var pathTextField: NSTextField!
    var browseButton: NSButton!
    var processButton: NSButton!
    var statusLabel: NSTextField!
    
    // 表格视图
    var tableView: NSTableView!
    
    // 默认屏蔽的失败用例列表（通过默认屏蔽项按钮添加）
    var defaultBlockedFailures: Set<String> = []
    
    // 会话屏蔽的失败用例列表（通过右键菜单临时屏蔽）
    var sessionBlockedFailures: Set<String> = []
    
    // 会话屏蔽的SN列表（通过当前失败用例筛选面板临时屏蔽）
    var sessionBlockedSNs: Set<String> = []
    
    // 会话屏蔽的通道号列表（通过当前失败用例筛选面板临时屏蔽）
    var sessionBlockedChannels: Set<String> = []
    
    // 合并的屏蔽列表（用于实际过滤）
    var blockedFailures: Set<String> {
        return defaultBlockedFailures.union(sessionBlockedFailures)
    }
    
    // 表格配置信息
    var tableConfig: [String: String] = [
        "sn": "PrimaryIdentity",
        "channel": "Fixture Channel ID"
    ]
    
    // 表格配置文件路径
    var tableConfigFilePath: String {
        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
        let configDir = appSupportDir + "/AtlasDataProcessor"
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true, attributes: nil)
        return configDir + "/table_config.json"
    }
    
    // 配置文件路径
    internal var configFilePath: String {
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return ""
        }
        let appDir = appSupportDir.appendingPathComponent("AtlasDataProcessor", isDirectory: true)
        try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("blocked_failures.json").path
    }
    
    // 操作按钮
    var saveFailHeadersButton: NSButton!
    var saveCSVButton: NSButton!
    var saveCSVPlusButton: NSButton!
    var exportJSONButton: NSButton!
    
    // MARK: - 数据
    var processor: AtlasDataProcessor?
    var isProcessing = false
    var statistics: [String: Any] = [:]
    var failures: [String] = []
    var processedData: [[String]] = []
    var processedDataPlus: [[String]] = []
    
    // MARK: - 折叠功能相关
    var groupedFailures: [GroupedFailure] = []
    var expandedGroups: Set<Int> = []
    
    // MARK: - 弹出式面板引用
    internal var blockFailPopoverController: BlockFailPopoverController?
    
    // MARK: - 生命周期
    override func windowDidLoad() {
        #if DEBUG
        print("🔍 HistoryWindowController: windowDidLoad 被调用")
        print("📌 窗口标题: \(window?.title ?? "未知")")
        print("📐 窗口尺寸: \(window?.frame.size.width ?? 0) x \(window?.frame.size.height ?? 0)")
        #endif
        super.windowDidLoad()
        setupUI()
        setupMouseTracking()
        #if DEBUG
        print("✅ HistoryWindowController: UI 设置完成")
        #endif
    }
    
    // 设置鼠标追踪
    private func setupMouseTracking() {
        // 为表格视图添加鼠标点击事件监听（处理左键单击）
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTableViewLeftClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        // 只处理左键点击
        clickGesture.buttonMask = 0x1
        tableView.addGestureRecognizer(clickGesture)
        
        // 为表格视图添加右键点击事件监听
        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTableViewRightClick(_:)))
        rightClickGesture.numberOfClicksRequired = 1
        // 只处理右键点击
        rightClickGesture.buttonMask = 0x2
        tableView.addGestureRecognizer(rightClickGesture)
    }
    
    // 处理表格视图的左键单击事件
    @objc private func handleTableViewLeftClick(_ gesture: NSClickGestureRecognizer) {
        #if DEBUG
        print("✅ 左键点击")
        #endif
        guard gesture.state == .ended else { return }
        
        let location = gesture.location(in: tableView)
        let row = tableView.row(at: location)
        
        if row != -1 {
            // 选中点击的行
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            
            // 显示菜单
            if let event = NSApplication.shared.currentEvent {
                // 直接调用 menuFor 方法生成菜单
                if let menu = tableView(tableView, menuFor: event) {
                    NSMenu.popUpContextMenu(menu, with: event, for: tableView)
                }
            }
        }
    }
    
    // 处理表格视图的右键点击事件
    @objc private func handleTableViewRightClick(_ gesture: NSClickGestureRecognizer) {
        #if DEBUG
        print("✅ 右键点击")
        #endif
        // 右键点击事件由系统的menuFor方法处理
        // 这里不需要做任何处理，让系统正常调用menuFor方法
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
            // 加载屏蔽的失败用例
            loadBlockedFailures()
            setupUI()
            setupMouseTracking()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // 清理资源
    }
    
    // 处理表格视图的鼠标按下事件
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        // 仅处理左键点击分组标题行的展开/折叠
        // 避免右键触发时提前 reload 导致菜单计算 groupIndex 发生错位
        guard event.type == .leftMouseDown else { return }
        
        if let tableView = self.tableView {
            // 将事件位置转换为表格视图坐标
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            
            if row != -1 {
                // 计算当前行对应的分组和位置
                let (groupIndex, isHeader, _) = getGroupInfo(forRow: row)
                
                if isHeader {
                    // 切换分组展开/折叠状态
                    if expandedGroups.contains(groupIndex) {
                        expandedGroups.remove(groupIndex)
                    } else {
                        expandedGroups.insert(groupIndex)
                    }
                    
                    // 暂时允许空选择，避免重新加载数据时自动选择行
                    tableView.allowsEmptySelection = true
                    tableView.reloadData()
                    tableView.deselectAll(nil)
                    tableView.allowsEmptySelection = false
                }
            }
        }
    }
}
