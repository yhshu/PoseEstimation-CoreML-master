//
//  Measure.swift
//  TurtleApp-CoreML
//
//

import UIKit

// 含有性能测量的相关方法的协议
protocol PerformanceMeasurementDelegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) // 更新性能测量数据
}

// 性能测量
class PerformanceMeasurement {
    
    var delegate: PerformanceMeasurementDelegate?
    
    var index: Int = -1                             // 测量数组的索引，记录最近 30 次
    var measurements: [Dictionary<String, Double>]  // 测量数组
    
    /// 初始化存储测量数据的数组
    init() {
        let measurement = [
            "start": CACurrentMediaTime(),          // 当前的绝对时间，以秒为单位
            "end": CACurrentMediaTime()
        ]
        measurements = Array<Dictionary<String, Double>>(repeating: measurement, count: 30)
        // 数组初始化，measurements 作为元素重复 30 项
    }
    
    /// 开始测量
    func start() {
        index += 1
        index %= 30
        measurements[index] = [:]   // 清空该字典
        
        label(for: index, with: "start")
    }
    
    /// 停止测量
    func stop() {
        label(for: index, with: "end")
        
        let beforeMeasurement = getBeforeMeasurment(for: index)  // 上一项测量数据
        let currentMeasurement = measurements[index]             // 当前测量数据
        
        // 计算推断时间、执行时间和 FPS (Frame Per Second)
        if let startTime = currentMeasurement["start"],
            let endInferenceTime = currentMeasurement["endInference"],
            let endTime = currentMeasurement["end"],
            let beforeStartTime = beforeMeasurement["start"] {
            delegate?.updateMeasure(inferenceTime: endInferenceTime - startTime,
                                    executionTime: endTime - startTime,
                                    fps: Int(1 / (startTime - beforeStartTime)))
        }
    }
    
    /// 在测量数组中记录 msg 字段为当前时间
    /// - Parameter msg: 测量信息的字段
    func label(with msg: String? = "") {
        label(for: index, with: msg)
    }
    
    /// 在测量数组的指定索引处，记录 msg 字段为当前时间
    /// - Parameter index: 存储历史测量信息的数组的索引
    /// - Parameter msg: 测量信息的字段
    private func label(for index: Int, with msg: String? = "") {
        if let message = msg {
            measurements[index][message] = CACurrentMediaTime()
        }
    }
    
    /// 获得上一项测量，便于计算执行时间和推断时间
    /// - Parameter index: 测量的索引
    /// - Returns: 上次测量的相关信息
    private func getBeforeMeasurment(for index: Int) -> Dictionary<String, Double> {
        return measurements[(index + 30 - 1) % 30]
    }
    
    // TODO: log
    func log() {
        
    }
}

class MeasureLogView: UIView {
    let etimeLabel = UILabel(frame: .zero)
    let fpsLabel = UILabel(frame: .zero)
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
