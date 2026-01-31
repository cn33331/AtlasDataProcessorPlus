//
//  DataReaderService.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Foundation

protocol DataReaderServiceDelegate: AnyObject {
    func dataReaderService(_ service: DataReaderService, didFindNewDataForChannel channel: Channel, data: [TestData])
    func dataReaderService(_ service: DataReaderService, didUpdateChannelStatus channel: Channel, status: Channel.ChannelStatus)
    func dataReaderService(_ service: DataReaderService, didClearChannelData channel: Channel)
}

class DataReaderService {
    weak var delegate: DataReaderServiceDelegate?
    
    private let basePath: URL
    private var monitoredChannels: [String: Channel] = [:] // key: "group-slot"
    private var filePositions: [String: UInt64] = [:] // key: "group-slot"
    private var isRunning: Bool = false
    private var lastScanTime: Date = Date()
    private let queue = DispatchQueue(label: "com.testmonitor.datareader", qos: .background)
    private var timer: DispatchSourceTimer?
    
    init(basePath: URL) {
        self.basePath = basePath
    }
    
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        
        // 启动定时器，每10ms检查一次
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer?.setEventHandler {
            self.checkFiles()
        }
        timer?.resume()
        // 立即扫描通道，不需要等待5秒
        scanChannels()
        lastScanTime = Date()
    }
    
    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }
    
    private func checkFiles() {
        // 每5秒扫描一次通道
        let now = Date()
        if now.timeIntervalSince(lastScanTime) > 5 {
            scanChannels()
            lastScanTime = now
        }
        
        // 检查所有监控的文件
        for (key, channel) in monitoredChannels {
            let filePath = basePath.appendingPathComponent(channel.name).appendingPathComponent("system").appendingPathComponent("records.csv")
            
            if FileManager.default.fileExists(atPath: filePath.path) {
                do {
                    let fileInfo = try FileManager.default.attributesOfItem(atPath: filePath.path)
                    let fileSize = fileInfo[.size] as! UInt64
                    let lastPosition = filePositions[key] ?? 0
                    
                    // 如果之前状态是"测试结束"，现在文件又出现了，说明开始新的测试
                    if channel.status == .ended {
                        channel.status = .running
                        channel.clearData()
                        filePositions[key] = 0
                        delegate?.dataReaderService(self, didClearChannelData: channel)
                        delegate?.dataReaderService(self, didUpdateChannelStatus: channel, status: .running)
                        continue
                    }
                    
                    // 如果有新数据
                    if fileSize > lastPosition {
                        let data = try Data(contentsOf: filePath)
                        if let content = String(data: data, encoding: .utf8) {
                            let lines = content.components(separatedBy: .newlines)
                            var newLines: [String] = []
                            var currentPosition: UInt64 = 0
                            
                            for line in lines {
                                let lineLength = line.utf8.count + 1 // +1 for newline
                                currentPosition += UInt64(lineLength)
                                
                                if currentPosition > lastPosition {
                                    newLines.append(line)
                                }
                            }
                            
                            if !newLines.isEmpty {
                                processNewLines(newLines, for: channel)
                                filePositions[key] = fileSize
                                channel.status = .running
                                delegate?.dataReaderService(self, didUpdateChannelStatus: channel, status: .running)
                            } else {
                                filePositions[key] = fileSize
                            }
                        }
                    }
                } catch {
                    print("Error reading file \(filePath): \(error)")
                }
            } else {
                // 文件消失，可能是测试结束
                if channel.status == .running || (filePositions[key] ?? 0) > 0 {
                    channel.status = .ended
                    delegate?.dataReaderService(self, didUpdateChannelStatus: channel, status: .ended)
                }
                filePositions[key] = 0
            }
        }
    }
    
    private func scanChannels() {
        do {
            let items = try FileManager.default.contentsOfDirectory(at: basePath, includingPropertiesForKeys: nil)
            var foundChannels: Set<String> = []
            
            for item in items {
                if item.hasDirectoryPath && item.lastPathComponent.contains("-") {
                    let nameParts = item.lastPathComponent.split(separator: "-")
                    if nameParts.count >= 2 {
                        let group = String(nameParts[0])
                        let slot = String(nameParts[1])
                        let channelKey = "\(group)-\(slot)"
                        
                        // 检查是否有system/records.csv文件
                        let recordsFile = item.appendingPathComponent("system").appendingPathComponent("records.csv")
                        if FileManager.default.fileExists(atPath: recordsFile.path) {
                            foundChannels.insert(channelKey)
                            
                            // 如果是新通道，添加监控
                            if !monitoredChannels.keys.contains(channelKey) {
                                let newChannel = Channel(group: group, slot: slot)
                                monitoredChannels[channelKey] = newChannel
                                filePositions[channelKey] = 0
                                delegate?.dataReaderService(self, didUpdateChannelStatus: newChannel, status: .running)
                            }
                        }
                    }
                }
            }
            
            // 移除不存在的通道
            for key in monitoredChannels.keys {
                if !foundChannels.contains(key) {
                    if let channel = monitoredChannels[key] {
                        channel.status = .ended
                        delegate?.dataReaderService(self, didUpdateChannelStatus: channel, status: .ended)
                    }
                }
            }
        } catch {
            print("Error scanning channels: \(error)")
        }
    }
    
    private func processNewLines(_ lines: [String], for channel: Channel) {
        var newTestData: [TestData] = []
        
        for line in lines {
            if line.isEmpty || line.starts(with: "attributeName,") {
                continue
            }
            
            if let testData = TestData.parse(from: line) {
                channel.addTestData(testData)
                newTestData.append(testData)
            }
        }
        
        if !newTestData.isEmpty {
            delegate?.dataReaderService(self, didFindNewDataForChannel: channel, data: newTestData)
        }
    }
    
    func getChannels() -> [Channel] {
        return Array(monitoredChannels.values)
    }
    
    func getChannel(for key: String) -> Channel? {
        return monitoredChannels[key]
    }
}
