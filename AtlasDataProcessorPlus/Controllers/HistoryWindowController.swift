// HistoryWindowController.swift
import Cocoa

class HistoryWindowController: NSWindowController {
    
    // MARK: - UI 组件
    private var pathTextField: NSTextField!
    private var browseButton: NSButton!
    private var processButton: NSButton!
    private var progressIndicator: NSProgressIndicator!
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
        
        // 进度指示器
        progressIndicator = NSProgressIndicator()
        progressIndicator.isIndeterminate = true
        progressIndicator.isHidden = true
        progressIndicator.style = .spinning
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(progressIndicator)
        
        // 状态标签
        statusLabel = NSTextField(labelWithString: "准备就绪")
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(statusLabel)
        
        // 统计信息面板
        let statsPanel = createStatisticsPanel()
        mainStack.addArrangedSubview(statsPanel)
        
        // 表格视图（显示失败记录）
        let tableContainer = createTableView()
        mainStack.addArrangedSubview(tableContainer)
        
        // 底部操作按钮
        let actionButtons = createActionButtons()
        mainStack.addArrangedSubview(actionButtons)
        
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
            mainStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            mainStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            mainStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            
            // 进度指示器固定大小
            progressIndicator.heightAnchor.constraint(equalToConstant: 20),
            
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
        
        // 标题
        let titleLabel = NSTextField(labelWithString: "历史数据处理器")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        
        // 路径标签
        let pathLabel = NSTextField(labelWithString: "数据目录:")
        pathLabel.font = NSFont.systemFont(ofSize: 12)
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(pathLabel)
        
        // 路径输入框
        pathTextField = NSTextField()
        pathTextField.placeholderString = "请选择包含 records.csv 文件的目录"
        pathTextField.font = NSFont.systemFont(ofSize: 12)
        pathTextField.lineBreakMode = .byTruncatingHead
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
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            
            // 路径标签
            pathLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            pathLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            pathLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // 路径输入框
            pathTextField.centerYAnchor.constraint(equalTo: pathLabel.centerYAnchor),
            pathTextField.leadingAnchor.constraint(equalTo: pathLabel.trailingAnchor, constant: 10),
            pathTextField.heightAnchor.constraint(equalToConstant: 24),
            
            // 浏览按钮
            browseButton.centerYAnchor.constraint(equalTo: pathTextField.centerYAnchor),
            browseButton.leadingAnchor.constraint(equalTo: pathTextField.trailingAnchor, constant: 10),
            browseButton.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor),
            browseButton.widthAnchor.constraint(equalToConstant: 80),
            
            // 处理按钮
            processButton.topAnchor.constraint(equalTo: pathTextField.bottomAnchor, constant: 20),
            processButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            processButton.widthAnchor.constraint(equalToConstant: 120),
            processButton.heightAnchor.constraint(equalToConstant: 32),
            processButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        
        return panel
    }
    
    // MARK: - 创建统计信息面板
    private func createStatisticsPanel() -> NSView {
        let panel = NSView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        panel.layer?.cornerRadius = 8
        panel.layer?.borderWidth = 1
        panel.layer?.borderColor = NSColor.separatorColor.cgColor
        
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        
        // 统计项目
        let statsItems = [
            ("文件数", "0"),
            ("参数数", "0"),
            ("失败数", "0"),
            ("成功率", "0%")
        ]
        
        for (title, value) in statsItems {
            let statView = createStatItem(title: title, value: value)
            stack.addArrangedSubview(statView)
        }
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),
            panel.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        return panel
    }
    
    private func createStatItem(title: String, value: String) -> NSView {
        let view = NSView()
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 11)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        valueLabel.alignment = .center
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        
        return view
    }
    
    // MARK: - 创建表格视图
    private func createTableView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 标题
        let tableTitle = NSTextField(labelWithString: "失败记录")
        tableTitle.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        tableTitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tableTitle)
        
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
        
        // 设置列
        let columns = [
            ("序号", 50),
            ("测试时间", 180),
            ("失败用例", 300),
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
            
            scrollView.topAnchor.constraint(equalTo: tableTitle.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
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
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
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
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
                
                if success {
                    self.statusLabel.stringValue = "处理完成"
                    
                    // 获取数据
                    self.processedData = processor.getFinalData()
                    self.processedDataPlus = processor.getFinalDataPlus()
                    
                    // 获取统计信息
                    self.statistics = processor.getStatistics()
                    self.failures = processor.getFailureSummary()
                    
                    // 更新UI
                    self.updateStatistics()
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
    
    // MARK: - 更新UI
    private func updateStatistics() {
        // 更新统计信息显示
        let fileCount = statistics["total_files"] as? Int ?? 0
        let paramCount = statistics["total_params"] as? Int ?? 0
        let failureCount = statistics["failure_count"] as? Int ?? 0
        let successRate = statistics["success_rate"] as? Double ?? 0
        
        // 获取统计面板中的标签并更新
        guard let statsPanel = contentViewController?.view.subviews.first?.subviews[2] as? NSView,
              let stack = statsPanel.subviews.first as? NSStackView,
              stack.arrangedSubviews.count >= 4 else {
            return
        }
        
        // 文件数
        if let fileView = stack.arrangedSubviews[0] as? NSView,
           let valueLabel = fileView.subviews.last as? NSTextField {
            valueLabel.stringValue = "\(fileCount)"
        }
        
        // 参数数
        if let paramView = stack.arrangedSubviews[1] as? NSView,
           let valueLabel = paramView.subviews.last as? NSTextField {
            valueLabel.stringValue = "\(paramCount)"
        }
        
        // 失败数
        if let failureView = stack.arrangedSubviews[2] as? NSView,
           let valueLabel = failureView.subviews.last as? NSTextField {
            valueLabel.stringValue = "\(failureCount)"
            valueLabel.textColor = failureCount > 0 ? .systemRed : .labelColor
        }
        
        // 成功率
        if let rateView = stack.arrangedSubviews[3] as? NSView,
           let valueLabel = rateView.subviews.last as? NSTextField {
            valueLabel.stringValue = String(format: "%.1f%%", successRate)
            valueLabel.textColor = successRate >= 90 ? .systemGreen : 
                                  successRate >= 70 ? .systemOrange : .systemRed
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
extension HistoryWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return failures.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView 
            ?? NSTableCellView()
        
        cell.identifier = identifier
        cell.textField?.stringValue = getCellValue(for: identifier.rawValue, row: row)
        
        return cell
    }
    
    private func getCellValue(for column: String, row: Int) -> String {
        guard row < failures.count else { return "" }
        
        let failure = failures[row]
        let components = failure.components(separatedBy: " | ")
        
        switch column {
        case "序号":
            return "\(row + 1)"
        case "测试时间":
            return components.count > 0 ? components[0] : "未知时间"
        case "失败用例":
            return components.count > 1 ? components[1] : "无具体用例"
        case "文件路径":
            return components.count > 2 ? components[2] : "未知文件"
        default:
            return ""
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20
    }
}
