//
//  Channel.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Foundation

class Channel {
    let group: String
    let slot: String
    var status: ChannelStatus = .waiting
    var failCount: Int = 0
    var passCount: Int = 0
    var totalCount: Int = 0
    var lastUpdate: String = "--"
    var testData: [TestData] = []
    var maxRows: Int = 1000
    var showFailOnly: Bool = false
    
    init(group: String, slot: String) {
        self.group = group
        self.slot = slot
    }
    
    var name: String {
        return "\(group)-\(slot)"
    }
    
    func addTestData(_ data: TestData) {
        testData.append(data)
        totalCount += 1
        
        if data.status == "PASS" {
            passCount += 1
        } else if data.status == "FAIL" {
            failCount += 1
        }
        
        // 限制最大行数
        while testData.count > maxRows {
            let removedData = testData.removeFirst()
            if removedData.status == "PASS" {
                passCount -= 1
            } else if removedData.status == "FAIL" {
                failCount -= 1
            }
            totalCount -= 1
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        lastUpdate = formatter.string(from: Date())
    }
    
    func clearData() {
        testData.removeAll()
        failCount = 0
        passCount = 0
        totalCount = 0
        lastUpdate = "--"
    }
    
    enum ChannelStatus: String {
        case waiting = "等待"
        case running = "运行中"
        case ended = "测试结束"
        case stopped = "已停止"
    }
}
