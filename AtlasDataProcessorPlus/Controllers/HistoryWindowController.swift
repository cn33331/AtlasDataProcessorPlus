// HistoryWindowController.swift
// Atlas 历史数据处理窗口控制器
// 重构：扁平表格 + 侧栏布局，参考小象测试台设计
//
// 功能实现分布在以下扩展文件中：
// - HistoryWindowController+UI.swift: 侧栏 + 工具栏 + 表格 UI
// - HistoryWindowController+Table.swift: 扁平表格视图代理
// - HistoryWindowController+Actions.swift: 按钮动作与业务逻辑
// - HistoryWindowController+Filter.swift: 搜索/筛选/排序逻辑

import Cocoa

// MARK: - 测试记录数据模型
struct TestRecord {
    let index: Int
    let sn: String
    let slotID: String
    let sBuild: String
    var status: String          // PASS / FAIL（屏蔽后可变为 PASS）
    let testTime: String
    let testName: String
    let measurementData: String // 测量数据摘要
    let filePath: String
    let rowData: [String]       // 完整行数据
    let headerRow: [String]     // 表头行（用于详情弹窗）
}

// MARK: - 历史数据处理窗口控制器
class HistoryWindowController: NSWindowController {
    
    // MARK: - UI 组件
    var pathTextField: NSTextField!
    var browseButton: NSButton!
    var processButton: NSButton!
    var statusLabel: NSTextField!
    /// 处理数据时的转圈进度指示器
    var progressIndicator: NSProgressIndicator!
    
    // 侧栏
    var sidebarView: NSView!
    var sidebarVisible = true
    /// 侧栏右侧分隔线（收起侧栏时一并隐藏）
    internal var sidebarSeparatorView: NSBox?
    /// 侧栏布局约束（收起时停用，避免与内部 184px 固定宽控件冲突导致约束被打破）
    internal var sidebarLeadingConstraint: NSLayoutConstraint?
    internal var sidebarWidthConstraint: NSLayoutConstraint?
    internal var sidebarSepLeadingConstraint: NSLayoutConstraint?
    internal var sidebarSepWidthConstraint: NSLayoutConstraint?
    /// 表格左边距约束：显示侧栏时锚到分隔线，收起时锚到主区域左缘
    internal var tableLeadingToSepConstraint: NSLayoutConstraint?
    internal var tableLeadingToMainConstraint: NSLayoutConstraint?
    /// 主区域和表格容器引用（toggleSidebar 懒创建备用约束时使用）
    internal var mainAreaView: NSView?
    internal var tableContainerView: NSView?
    
    // 状态过滤按钮
    var allFilterButton: NSButton!
    var passFilterButton: NSButton!
    var failFilterButton: NSButton!
    var statusSummaryLabel: NSTextField!
    
    // 日期过滤
    var dateFromPicker: NSDatePicker!
    var dateToPicker: NSDatePicker!
    
    // 搜索框
    var searchField: NSSearchField!
    
    // SLOT / S_BUILD 统计容器
    var slotStatsView: NSView!
    var sBuildStatsView: NSView!
    
    // 工具栏
    var toolbarView: NSView!
    var reparseButton: NSButton!
    var exportCSVButton: NSButton!
    
    // 表格
    var tableView: NSTableView!
    
    // 屏蔽管理按钮
    var defaultBlockButton: NSButton!
    var currentFailFilterButton: NSButton!
    
    // MARK: - 屏蔽数据
    var sessionBlockedFailures: Set<String> = []
    var sessionBlockedSNs: Set<String> = []
    var sessionBlockedChannels: Set<String> = []
    var sessionBlockedSBuilds: Set<String> = []
    
    var blockedFailures: Set<String> {
        return AppConfig.shared.blockedFailures.union(sessionBlockedFailures)
    }
    
    // MARK: - 数据
    var processor: AtlasDataProcessor?
    var isProcessing = false
    var statistics: [String: Any] = [:]
    var failures: [String] = []
    var processedDataPlus: [[String]] = []
    var upperLimitRow: [String] = []   // processedDataPlus[1] 上限行
    var lowerLimitRow: [String] = []   // processedDataPlus[2] 下限行
    
    // 扁平记录
    var allRecords: [TestRecord] = []       // 所有记录（未过滤）
    var filteredRecords: [TestRecord] = []  // 当前显示记录
    
    // 过滤/排序状态
    var statusFilter: String = "all"           // all / pass / fail
    var excludedSlots: Set<String> = []         // 被排除的 SLOT（点击取消勾选）
    var excludedSBuilds: Set<String> = []       // 被排除的 S_BUILD
    var searchText: String = ""
    /// 搜索防抖 Timer（用户停止输入 0.3s 后才执行筛选）
    internal var searchDebounceTimer: Timer?
    /// 键盘快捷键本地事件监听（Cmd+F 聚焦搜索 / Escape 清除搜索）
    internal var keyEventMonitor: Any?
    var currentSortField: String = "index"  // index / slot / sn / time
    var sortAscending: Bool = true
    var dateFrom: Date?
    var dateTo: Date?
    
    // 弹出式面板引用
    internal var blockFailPopoverController: BlockFailPopoverController?
    
    // SLOT / S_BUILD 统计高度约束（动态调整）
    internal var slotStatsHeightConstraint: NSLayoutConstraint?
    internal var sBuildStatsHeightConstraint: NSLayoutConstraint?
    
    // MARK: - 生命周期
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    private func setupMouseTracking() {
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleTableViewClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        clickGesture.buttonMask = 0x1
        tableView.addGestureRecognizer(clickGesture)
        
        // 双击查看详情
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        doubleClickGesture.buttonMask = 0x1
        tableView.addGestureRecognizer(doubleClickGesture)
        
        // Enter 键查看详情（与双击等效）
        (tableView as? ContextMenuTableView)?.enterKeyHandler = { [weak self] in
            guard let self = self else { return }
            let row = self.tableView.selectedRow
            if row >= 0, row < self.filteredRecords.count {
                self.showDetailModal(for: self.filteredRecords[row])
            }
        }
    }
    
    @objc private func handleTableViewClick(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: tableView)
        let row = tableView.row(at: location)
        if row != -1 {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }
    
    @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let location = gesture.location(in: tableView)
        let row = tableView.row(at: location)
        if row >= 0, row < filteredRecords.count {
            showDetailModal(for: filteredRecords[row])
        }
    }
    
    // MARK: - 初始化
    override init(window: NSWindow?) {
        super.init(window: window)
        setupUI()
        setupMouseTracking()
        setupKeyboardShortcuts()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 键盘快捷键
    /// 用本地事件监听实现快捷键。
    /// 不用 performKeyEquivalent：NSWindowController 不在 key equivalent 的 responder 链上，
    /// 且无修饰键的 Escape 根本不走 performKeyEquivalent 路径（只走 keyDown）。
    private func setupKeyboardShortcuts() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // 只处理本窗口的事件（详情弹窗等其他窗口不受影响）
            if let eventWindow = event.window, eventWindow !== self.window { return event }
            
            // Cmd+F → 聚焦搜索框并全选，便于直接输入
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                self.window?.makeFirstResponder(self.searchField)
                self.searchField?.selectText(nil)
                return nil
            }
            
            // Escape → 清除搜索文字 + 刷新筛选 + 焦点转回表格
            if event.keyCode == 53 {
                let hasSearch = !(self.searchField?.stringValue.isEmpty ?? true)
                if hasSearch || self.searchField?.currentEditor() != nil {
                    self.searchField?.stringValue = ""
                    self.searchText = ""
                    self.searchDebounceTimer?.invalidate()
                    self.applyFilters()
                    self.window?.makeFirstResponder(self.tableView)
                    return nil
                }
            }
            
            return event
        }
    }
    
    deinit {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}