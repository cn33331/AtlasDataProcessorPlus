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
    
    // 侧栏
    var sidebarView: NSView!
    var sidebarVisible = true
    
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
    var sortSlotButton: NSButton!
    var sortSNButton: NSButton!
    var sortTimeButton: NSButton!
    var resetSortButton: NSButton!
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
    var processedData: [[String]] = []
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
        debugLog("🔍 [HW] windowDidLoad - NOT EXPECTED (programmatic window), frame: \(window?.frame ?? .zero)")
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
        debugLog("🔍 [HW] init(window:) - window frame: \(window?.frame ?? .zero)")
        setupUI()
        debugLog("🔍 [HW] init(window:) - after setupUI, window frame: \(window?.frame ?? .zero)")
        setupMouseTracking()
        loadTableConfig()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}