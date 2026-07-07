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
        return channelControllers.values.map { $0.channel }.sorted { channel1, channel2 in
            let group1 = Int(channel1.group.replacingOccurrences(of: "group", with: "")) ?? 0
            let group2 = Int(channel2.group.replacingOccurrences(of: "group", with: "")) ?? 0
            
            if group1 != group2 {
                return group1 < group2
            }
            
            let slot1 = Int(channel1.slot.replacingOccurrences(of: "slot", with: "")) ?? 0
            let slot2 = Int(channel2.slot.replacingOccurrences(of: "slot", with: "")) ?? 0
            return slot1 < slot2
        }
    }
}