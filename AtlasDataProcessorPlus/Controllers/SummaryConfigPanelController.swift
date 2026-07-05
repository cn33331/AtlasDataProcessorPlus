//
//  SummaryConfigPanelController.swift
//  AtlasDataProcessorPlus
//
//  Created by gdlocal on 2026/7/5.
//

import Cocoa

class SummaryConfigPanelController: NSWindowController {
    
    private var fontSizePopUp: NSPopUpButton!
    private var fontColorWell: NSColorWell!
    private var failColorWell: NSColorWell!
    private var passColorWell: NSColorWell!
    private var xPositionField: NSTextField!
    private var yPositionField: NSTextField!
    private var currentPositionLabel: NSTextField!
    private var applyButton: NSButton!
    private var closeButton: NSButton!
    
    private var delegate: TabbedToolWindowController?
    private var presetButtons: [Int: NSPoint] = [:]
    private var directionButtonsDict: [Int: (Int, Int)] = [:]
    
    init(delegate: TabbedToolWindowController?) {
        self.delegate = delegate
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "汇总窗口配置"
        window.center()
        super.init(window: window)
        setupUI()
        loadCurrentConfig()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func createRowStack(label: NSView, field: NSView) -> NSStackView {
        let rowStack = NSStackView()
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .centerY
        rowStack.addArrangedSubview(label)
        rowStack.addArrangedSubview(field)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return rowStack
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let mainView = NSView()
        mainView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainView)
        
        NSLayoutConstraint.activate([
            mainView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        let fontSizeLabel = NSTextField(labelWithString: "字体大小:")
        fontSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        fontSizePopUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 100, height: 25))
        fontSizePopUp.translatesAutoresizingMaskIntoConstraints = false
        for size in [10, 12, 14, 16, 18, 20, 22, 24] {
            fontSizePopUp.addItem(withTitle: "\(size)")
        }
        
        let fontColorLabel = NSTextField(labelWithString: "字体颜色:")
        fontColorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        fontColorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 50, height: 25))
        fontColorWell.translatesAutoresizingMaskIntoConstraints = false
        fontColorWell.isBordered = true
        
        let failColorLabel = NSTextField(labelWithString: "FAIL颜色:")
        failColorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        failColorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 50, height: 25))
        failColorWell.translatesAutoresizingMaskIntoConstraints = false
        failColorWell.isBordered = true
        
        let passColorLabel = NSTextField(labelWithString: "PASS颜色:")
        passColorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        passColorWell = NSColorWell(frame: NSRect(x: 0, y: 0, width: 50, height: 25))
        passColorWell.translatesAutoresizingMaskIntoConstraints = false
        passColorWell.isBordered = true
        
        let positionLabel = NSTextField(labelWithString: "窗口位置:")
        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let positionStack = NSStackView()
        positionStack.translatesAutoresizingMaskIntoConstraints = false
        positionStack.orientation = .horizontal
        positionStack.spacing = 8
        
        let xLabel = NSTextField(labelWithString: "X:")
        xLabel.translatesAutoresizingMaskIntoConstraints = false
        xLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        xPositionField = NSTextField(frame: NSRect(x: 0, y: 0, width: 60, height: 25))
        xPositionField.translatesAutoresizingMaskIntoConstraints = false
        xPositionField.isBordered = true
        xPositionField.alignment = .right
        xPositionField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let yLabel = NSTextField(labelWithString: "Y:")
        yLabel.translatesAutoresizingMaskIntoConstraints = false
        yLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        yPositionField = NSTextField(frame: NSRect(x: 0, y: 0, width: 60, height: 25))
        yPositionField.translatesAutoresizingMaskIntoConstraints = false
        yPositionField.isBordered = true
        yPositionField.alignment = .right
        yPositionField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        positionStack.addArrangedSubview(xLabel)
        positionStack.addArrangedSubview(xPositionField)
        positionStack.addArrangedSubview(yLabel)
        positionStack.addArrangedSubview(yPositionField)
        
        let presetPositions: [(name: String, offset: NSPoint)] = [
            ("左上", NSPoint(x: 20, y: -20)),
            ("右上", NSPoint(x: -20, y: -20)),
            ("左下", NSPoint(x: 20, y: 20)),
            ("右下", NSPoint(x: -20, y: 20)),
            ("居中", NSPoint(x: 0, y: 0))
        ]
        let presetStack = NSStackView()
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        presetStack.orientation = .horizontal
        presetStack.spacing = 4
        for (index, preset) in presetPositions.enumerated() {
            let btn = NSButton(title: preset.name, target: nil, action: nil)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.bezelStyle = .rounded
            btn.target = self
            btn.action = #selector(moveToPresetAction(_:))
            btn.tag = index
            presetButtons[index] = preset.offset
            presetStack.addArrangedSubview(btn)
        }
        
        let directionButtons: [(name: String, delta: (Int, Int))] = [
            ("↑", (0, -20)),
            ("↓", (0, 20)),
            ("←", (-20, 0)),
            ("→", (20, 0))
        ]
        let directionStack = NSStackView()
        directionStack.translatesAutoresizingMaskIntoConstraints = false
        directionStack.orientation = .horizontal
        directionStack.spacing = 4
        for (index, dir) in directionButtons.enumerated() {
            let btn = NSButton(title: dir.name, target: nil, action: nil)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.bezelStyle = .rounded
            btn.target = self
            btn.action = #selector(moveByDeltaAction(_:))
            btn.tag = index
            directionButtonsDict[index] = dir.delta
            directionStack.addArrangedSubview(btn)
        }
        
        currentPositionLabel = NSTextField(labelWithString: "当前位置: --")
        currentPositionLabel.translatesAutoresizingMaskIntoConstraints = false
        currentPositionLabel.textColor = NSColor.secondaryLabelColor
        
        let positionControlStack = NSStackView()
        positionControlStack.translatesAutoresizingMaskIntoConstraints = false
        positionControlStack.orientation = .vertical
        positionControlStack.spacing = 8
        positionControlStack.addArrangedSubview(positionStack)
        positionControlStack.addArrangedSubview(currentPositionLabel)
        positionControlStack.addArrangedSubview(presetStack)
        positionControlStack.addArrangedSubview(directionStack)
        
        applyButton = NSButton(title: "应用", target: self, action: #selector(applyConfig))
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        
        closeButton = NSButton(title: "关闭", target: self, action: #selector(closePanel))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonStack = NSStackView()
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 16
        buttonStack.addArrangedSubview(applyButton)
        buttonStack.addArrangedSubview(closeButton)
        
        let verticalStack = NSStackView()
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.orientation = .vertical
        verticalStack.spacing = 16
        
        let fontSizeRow = createRowStack(label: fontSizeLabel, field: fontSizePopUp)
        let fontColorRow = createRowStack(label: fontColorLabel, field: fontColorWell)
        let failColorRow = createRowStack(label: failColorLabel, field: failColorWell)
        let passColorRow = createRowStack(label: passColorLabel, field: passColorWell)
        let positionRow = createRowStack(label: positionLabel, field: positionControlStack)
        
        verticalStack.addArrangedSubview(fontSizeRow)
        verticalStack.addArrangedSubview(fontColorRow)
        verticalStack.addArrangedSubview(failColorRow)
        verticalStack.addArrangedSubview(passColorRow)
        verticalStack.addArrangedSubview(positionRow)
        
        verticalStack.addArrangedSubview(buttonStack)
        
        mainView.addSubview(verticalStack)
        
        NSLayoutConstraint.activate([
            verticalStack.leadingAnchor.constraint(equalTo: mainView.leadingAnchor),
            verticalStack.trailingAnchor.constraint(equalTo: mainView.trailingAnchor),
            verticalStack.topAnchor.constraint(equalTo: mainView.topAnchor),
            verticalStack.bottomAnchor.constraint(equalTo: mainView.bottomAnchor)
        ])
    }
    
    private func loadCurrentConfig() {
        fontSizePopUp.selectItem(withTitle: "\(AppConfig.shared.summaryFontSize)")
        fontColorWell.color = NSColor(hexString: AppConfig.shared.summaryFontColor)
        failColorWell.color = NSColor(hexString: AppConfig.shared.summaryFailColor)
        passColorWell.color = NSColor(hexString: AppConfig.shared.summaryPassColor)
        
        if let window = delegate?.window {
            xPositionField.stringValue = "\(Int(window.frame.origin.x))"
            yPositionField.stringValue = "\(Int(window.frame.origin.y))"
            currentPositionLabel.stringValue = "当前位置: (\(Int(window.frame.origin.x)), \(Int(window.frame.origin.y)))"
        } else {
            xPositionField.stringValue = "\(AppConfig.shared.summaryWindowX)"
            yPositionField.stringValue = "\(AppConfig.shared.summaryWindowY)"
            currentPositionLabel.stringValue = "当前位置: (\(AppConfig.shared.summaryWindowX), \(AppConfig.shared.summaryWindowY))"
        }
    }
    
    @objc private func applyConfig() {
        #if DEBUG
        print("🔧 SummaryConfigPanelController: applyConfig() 开始")
        #endif
        
        if let sizeStr = fontSizePopUp.selectedItem?.title, let size = Int(sizeStr) {
            AppConfig.shared.summaryFontSize = size
            #if DEBUG
            print("🔧 字体大小: \(size)")
            #endif
        }
        
        let fontColorHex = fontColorWell.color.toHexString()
        let failColorHex = failColorWell.color.toHexString()
        let passColorHex = passColorWell.color.toHexString()
        
        AppConfig.shared.summaryFontColor = fontColorHex
        AppConfig.shared.summaryFailColor = failColorHex
        AppConfig.shared.summaryPassColor = passColorHex
        
        #if DEBUG
        print("🔧 字体颜色: \(fontColorHex), FAIL颜色: \(failColorHex), PASS颜色: \(passColorHex)")
        #endif
        
        if let x = Int(xPositionField.stringValue),
           let y = Int(yPositionField.stringValue) {
            AppConfig.shared.summaryWindowX = x
            AppConfig.shared.summaryWindowY = y
            #if DEBUG
            print("🔧 窗口位置: (\(x), \(y))")
            #endif
            if let window = delegate?.window {
                let newFrame = NSRect(x: CGFloat(x), y: CGFloat(y), width: window.frame.width, height: window.frame.height)
                window.setFrame(newFrame, display: true)
            }
        }
        
        #if DEBUG
        print("🔧 delegate: \(delegate != nil ? "存在" : "nil")")
        #endif
        
        AppConfig.shared.saveConfigToFile()
        delegate?.updateConfig()
        
        #if DEBUG
        print("🔧 SummaryConfigPanelController: applyConfig() 完成")
        #endif
        
        closePanel()
    }
    
    @objc private func closePanel() {
        window?.orderOut(nil)
    }
    
    @objc private func moveToPresetAction(_ sender: NSButton) {
        guard let offset = presetButtons[sender.tag],
              let targetWindow = delegate?.window else { return }
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        var newX: CGFloat
        var newY: CGFloat
        
        if offset.x == 0 {
            newX = (screenFrame.width - targetWindow.frame.width) / 2
        } else if offset.x > 0 {
            newX = offset.x
        } else {
            newX = screenFrame.width - targetWindow.frame.width + offset.x
        }
        
        if offset.y == 0 {
            newY = (screenFrame.height - targetWindow.frame.height) / 2
        } else if offset.y > 0 {
            newY = offset.y
        } else {
            newY = screenFrame.height - targetWindow.frame.height + offset.y
        }
        
        targetWindow.setFrame(NSRect(x: newX, y: newY, width: targetWindow.frame.width, height: targetWindow.frame.height), display: true)
        updatePositionFields(x: Int(newX), y: Int(newY))
    }
    
    @objc private func moveByDeltaAction(_ sender: NSButton) {
        guard let delta = directionButtonsDict[sender.tag],
              let targetWindow = delegate?.window else { return }
        
        let currentX = Int(targetWindow.frame.origin.x)
        let currentY = Int(targetWindow.frame.origin.y)
        let newX = currentX + delta.0
        let newY = currentY + delta.1
        
        targetWindow.setFrame(NSRect(x: CGFloat(newX), y: CGFloat(newY), width: targetWindow.frame.width, height: targetWindow.frame.height), display: true)
        updatePositionFields(x: newX, y: newY)
    }
    
    private func updatePositionFields(x: Int, y: Int) {
        xPositionField.stringValue = "\(x)"
        yPositionField.stringValue = "\(y)"
        currentPositionLabel.stringValue = "当前位置: (\(x), \(y))"
    }
}

