// TableConfigPopoverController.swift
// 用于表格配置信息的弹出式面板控制器

import Cocoa

class TableConfigPopoverController: NSViewController {
    
    // 文本字段
    private var snTextField: NSTextField!
    private var channelTextField: NSTextField!
    
    // 配置信息
    var sn: String = "PrimaryIdentity"
    var channel: String = "Fixture Channel ID"
    
    // 回调闭包
    var completionHandler: ((String, String) -> Void)?
    
    // 弹出式面板
    private weak var popover: NSPopover?
    
    // 设置弹出式面板引用
    func setPopover(_ popover: NSPopover) {
        self.popover = popover
    }
    
    override func loadView() {
        // 创建主视图
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        self.view = view
        
        // 创建布局
        setupUI()
    }
    
    private func setupUI() {
        // 标题
        let titleLabel = NSTextField(labelWithString: "表格配置信息")
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // SN 标签
        let snLabel = NSTextField(labelWithString: "SN:")
        snLabel.font = NSFont.systemFont(ofSize: 14)
        snLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(snLabel)
        
        // SN 文本字段
        snTextField = NSTextField()
        snTextField.placeholderString = "PrimaryIdentity"
        snTextField.font = NSFont.systemFont(ofSize: 14)
        snTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(snTextField)
        
        // 通道号标签
        let channelLabel = NSTextField(labelWithString: "通道号:")
        channelLabel.font = NSFont.systemFont(ofSize: 14)
        channelLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelLabel)
        
        // 通道号文本字段
        channelTextField = NSTextField()
        channelTextField.placeholderString = "Fixture Channel ID"
        channelTextField.font = NSFont.systemFont(ofSize: 14)
        channelTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelTextField)
        
        // 按钮容器
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // 取消按钮
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.font = NSFont.systemFont(ofSize: 12)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        // 确定按钮
        let okButton = NSButton(title: "确定", target: self, action: #selector(ok))
        okButton.bezelStyle = .rounded
        okButton.font = NSFont.systemFont(ofSize: 12)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(okButton)
        
        // 布局约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // SN 标签
            snLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            snLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // SN 文本字段
            snTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 26),
            snTextField.leadingAnchor.constraint(equalTo: snLabel.trailingAnchor, constant: 10),
            snTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            snTextField.heightAnchor.constraint(equalToConstant: 24),
            
            // 通道号标签
            channelLabel.topAnchor.constraint(equalTo: snTextField.bottomAnchor, constant: 20),
            channelLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 通道号文本字段
            channelTextField.topAnchor.constraint(equalTo: snTextField.bottomAnchor, constant: 16),
            channelTextField.leadingAnchor.constraint(equalTo: channelLabel.trailingAnchor, constant: 10),
            channelTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            channelTextField.heightAnchor.constraint(equalToConstant: 24),
            
            // 按钮容器
            buttonContainer.topAnchor.constraint(equalTo: channelTextField.bottomAnchor, constant: 30),
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // 按钮
            cancelButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -80),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            okButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            okButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 80)
        ])
        
        // 设置初始值
        snTextField.stringValue = sn
        channelTextField.stringValue = channel
    }
    
    @objc private func cancel() {
        print("🔄 TableConfigPopoverController: cancel() 被调用")
        // 关闭弹出式面板
        popover?.close()
    }
    
    @objc private func ok() {
        print("🔄 TableConfigPopoverController: ok() 被调用")
        
        // 获取输入值
        let snValue = snTextField.stringValue.trimmingCharacters(in: .whitespaces)
        let channelValue = channelTextField.stringValue.trimmingCharacters(in: .whitespaces)
        
        // 调用回调
        completionHandler?(snValue, channelValue)
        
        // 关闭弹出式面板
        popover?.close()
    }
    
    deinit {
        print("TableConfigPopoverController 被释放")
    }
}
