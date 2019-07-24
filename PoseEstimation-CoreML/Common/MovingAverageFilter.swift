//
//  MovingAverageFilter.swift
//  PoseEstimation-CoreML
//
//

import UIKit

// 为 Core Graphics 库中的 CGPoint 扩展运算，用于移动平均的计算
extension CGPoint {
    
    /// CGPoint 的加法
    /// - Parameter lhs: 式子左边 left hand side
    /// - Parameter rhs: 式子右边 right hand side
    /// - Returns: 相加结果
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    /// CGPoint 的除法
    /// - Parameter lhs: 式子左边 left hand side
    /// - Parameter rhs: 式子右边 right hand side，注意不能为 0
    /// - Returns: 相除结果
    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        guard rhs != 0.0 else { return lhs }   // 除数为 0，直接返回 lhs
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

// 移动平均过滤器
// 移动平均 (moving average) 是分析时间序列数据的工具
// 作用是消除短期波动的影响，反映序列的长期趋势或周期
class MovingAverageFilter {
    var elements: [PredictedPoint?] = []  // 预测点数组
    private var limit: Int
    
    init(limit: Int) {
        guard limit > 0 else {
            fatalError("limit should be uppered than 0 in MovingAverageFilter init(limit:)")
        }
        self.elements = []  // 清空数组
        self.limit = limit
    }
    
    /// 添加预测点，如超出数量限制将移除之前添加的点
    /// - Parameter element: 预测点
    func add(element: PredictedPoint?) {
        elements.append(element)
        while self.elements.count > self.limit {
            self.elements.removeFirst()
        }
    }
    
    /// 获得平均值
    /// - Returns: 使用移动平均获得的预测点
    func averagedValue() -> PredictedPoint? {
        // compactMap 返回一个数组，其中包含使用序列的每个元素调用给定转换的非零结果
        // $0 $1 指代闭包的参数
        let nonOptionalPoints: [CGPoint] = elements.compactMap{ $0?.maxPoint }
        let nonOptionalConfidences: [Double] = elements.compactMap{ $0?.maxConfidence }
        guard !nonOptionalPoints.isEmpty && !nonOptionalConfidences.isEmpty else { return nil }
        
        // reduce 返回使用给定闭包组合序列元素的结果，参数是初始值
        let sumPoint = nonOptionalPoints.reduce( CGPoint.zero ) { $0 + $1 }
        let sumConfidence = nonOptionalConfidences.reduce( 0.0 ) { $0 + $1 }
        return PredictedPoint(maxPoint: sumPoint / CGFloat(nonOptionalPoints.count), maxConfidence: sumConfidence)
    }
}
