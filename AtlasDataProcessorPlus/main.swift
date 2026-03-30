// main.swift
import Cocoa

print("🎬 main.swift 开始执行")

// 创建 AppDelegate 实例
let delegate = AppDelegate()

// 获取共享的 NSApplication 实例
let app = NSApplication.shared
app.delegate = delegate

// 设置应用激活策略为常规应用
app.setActivationPolicy(.regular)

// 创建基本的应用菜单（macOS 应用必须有菜单）
setupApplicationMenu()

print("✅ NSApplication 配置完成，准备运行")

// 运行应用
NSApp.run()

// ======== 辅助函数 ========
func setupApplicationMenu() {
    print("📋 设置应用菜单")
    
    let mainMenu = NSMenu()
    
    // 应用菜单 (Atlas Data Processor Plus)
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu(title: "Atlas Data Processor Plus")
    
    appMenu.addItem(NSMenuItem(
        title: "关于 Atlas Data Processor Plus",
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
        keyEquivalent: ""
    ))
    
    appMenu.addItem(NSMenuItem.separator())
    
    appMenu.addItem(NSMenuItem(
        title: "退出 Atlas Data Processor Plus",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    ))
    
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)
    
    // 文件菜单
    let fileMenuItem = NSMenuItem()
    let fileMenu = NSMenu(title: "文件")
    
    fileMenu.addItem(NSMenuItem(
        title: "打开...",
        action: nil,
        keyEquivalent: "o"
    ))
    
    fileMenu.addItem(NSMenuItem.separator())
    
    // 添加监控工具菜单项
    let monitoringMenuItem = NSMenuItem(
        title: "监控工具",
        action: #selector(AppDelegate.showMonitoringTool(_:)),
        keyEquivalent: "m"
    )
    monitoringMenuItem.target = delegate
    fileMenu.addItem(monitoringMenuItem)
    
    fileMenu.addItem(NSMenuItem.separator())
    
    // 添加历史数据菜单项
    let historyMenuItem = NSMenuItem(
        title: "历史数据",
        action: #selector(AppDelegate.showHistoryWindow(_:)),
        keyEquivalent: "h"
    )
    historyMenuItem.target = delegate
    fileMenu.addItem(historyMenuItem)
    
    #if DEBUG
    print("📌 监控工具菜单项已添加")
    print("   - target: \(delegate)")
    print("   - action: \(Selector("showMonitoringTool:"))")
    print("📌 历史数据菜单项已添加")
    print("   - target: \(delegate)")
    print("   - action: \(Selector("showHistoryWindow:"))")
    #endif
    
    fileMenuItem.submenu = fileMenu
    mainMenu.addItem(fileMenuItem)
    
    // 设置应用主菜单
    NSApp.mainMenu = mainMenu
    
    print("✅ 菜单设置完成")
}

// 确保应用激活
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    print("🔔 激活应用")
    NSApp.activate(ignoringOtherApps: true)
    
    // 如果还没有窗口，强制创建一个
    if NSApp.windows.isEmpty {
        print("⚠️ 没有检测到窗口，尝试创建")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "测试窗口"
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
