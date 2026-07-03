//
//  MonitorManager.swift
//  AtlasDataProcessorPlus
//
//  Created by gdlocal on 2026/7/3.
//

import Cocoa

class MonitorManager {
    static let shared = MonitorManager()
    
    private var refreshTimer: Timer?
    private var isRunning: Bool = false
    
    var onDataUpdate: (() -> Void)?
    
    private init() {}
    
    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        refreshTimer = Timer(timeInterval: 1.0,
                            target: self,
                            selector: #selector(refreshData),
                            userInfo: nil,
                            repeats: true)
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
    
    func stopMonitoring() {
        isRunning = false
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @objc private func refreshData() {
        onDataUpdate?()
    }
    
    func getChannels() -> [Channel] {
        guard let delegate = NSApp.delegate as? AppDelegate,
              let mainWindowController = delegate.mainWindowController else {
            return []
        }
        
        let channelControllers = mainWindowController.channelControllers
        return channelControllers.values.map { $0.channel }.sorted { $0.name < $1.name }
    }
}