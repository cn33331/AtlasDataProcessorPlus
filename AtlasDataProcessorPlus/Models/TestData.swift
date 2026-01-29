//
//  TestData.swift
//  TestMonitorApp
//
//  Created by Your Name on 2026-01-29.
//

import Foundation

class TestData {
    let testName: String
    let upperLimit: String
    let measurementValue: String
    let lowerLimit: String
    let measurementUnits: String
    let status: String
    
    init(testName: String, upperLimit: String, measurementValue: String, lowerLimit: String, measurementUnits: String, status: String) {
        self.testName = testName
        self.upperLimit = upperLimit
        self.measurementValue = measurementValue
        self.lowerLimit = lowerLimit
        self.measurementUnits = measurementUnits
        self.status = status
    }
    
    static func parse(from csvLine: String) -> TestData? {
        let components = csvLine.components(separatedBy: ",")
        if components.count < 17 {
            return nil
        }
        
        var testName: String
        var measurementValue: String
        
        if components[0].isEmpty {
            testName = "\(components[2])/\(components[3])/\(components[4])"
            measurementValue = components[7]
        } else {
            testName = components[0]
            measurementValue = components[1]
        }
        
        let upperLimit = components[6]
        let lowerLimit = components[8]
        let measurementUnits = components[10]
        let status = components[12]
        
        return TestData(
            testName: testName,
            upperLimit: upperLimit,
            measurementValue: measurementValue,
            lowerLimit: lowerLimit,
            measurementUnits: measurementUnits,
            status: status
        )
    }
}
