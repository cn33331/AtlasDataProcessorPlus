//  AppDelegate.swift
import Cocoa

// 移除 @main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var mainWindowController: MainWindowController?
    var historyWindowController: HistoryWindowController?

    override init() {
        super.init()
        #if DEBUG
        print("🏗️ AppDelegate: 初始化")
        #endif
    }
    
    @objc public func showHistoryWindow(_ sender: Any?) {
        #if DEBUG
        print("🔍 AppDelegate: showHistoryWindow 被调用")
        print("📌 historyWindowController 状态: \(historyWindowController == nil ? "nil" : "已存在")")
        #endif
        
        if historyWindowController == nil {
            #if DEBUG
            print("➕ AppDelegate: 创建新的 HistoryWindowController")
            #endif
            historyWindowController = HistoryWindowController.createAndShow()
        } else {
            #if DEBUG
            print("🔄 AppDelegate: 显示已存在的 HistoryWindowController")
            #endif
            historyWindowController?.window?.makeKeyAndOrderFront(sender)
        }
        
        #if DEBUG
        print("✅ AppDelegate: showHistoryWindow 完成")
        #endif
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("🚀 应用启动开始 - AppDelegate 被调用！")
        
        // 创建主窗口控制器
        mainWindowController = MainWindowController()
        
        // 显示窗口
        mainWindowController?.showWindow(nil)
        
        // ⭐️ 关键修复：强制激活应用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 激活应用
            NSApp.activate(ignoringOtherApps: true)
            
            // 确保窗口在最前
            self.mainWindowController?.window?.orderFrontRegardless()
            self.mainWindowController?.window?.makeKey()
            
            print("✅ 应用已激活，窗口应在最前")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("🔚 应用即将终止")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
