//
//  PredictedPoint.swift
//  PoseEstimation-CoreML
//
//

import CoreGraphics

struct PredictedPoint {
    let maxPoint: CGPoint       // 最大概率对应的点
    let maxConfidence: Double   // 最大的概率值
}
