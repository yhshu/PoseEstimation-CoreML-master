//
//  HeatmapPostProcessor.swift
//  PoseEstimation-CoreML
//
//

import Foundation
import CoreML

// 在 Core ML 框架计算出热图后，进行热图的后处理
class HeatmapPostProcessor {
    
    /// 将 Core ML 生成的 heatmap 转换为点
    /// - Parameter heatmaps: 热图；MLMultiArray 是用于模型的特征输入或特征输出的多维数组
    /// - Returns: 预测点，每个通道以最大置信度作为预测结果
    func convertToPredictedPoints(from heatmaps: MLMultiArray) -> [PredictedPoint?] {
        guard heatmaps.shape.count >= 3 else {
            print("heatmap's shape is invalid. \(heatmaps.shape)")
            return []
        }
        let keypoint_number = heatmaps.shape[0].intValue   // 关键点数量
        let heatmap_w = heatmaps.shape[1].intValue         // 热图宽度
        let heatmap_h = heatmaps.shape[2].intValue         // 热图高度
        
        var n_kpoints = (0 ..< keypoint_number).map { _ -> PredictedPoint? in
            return nil
        }
        
        for k in 0 ..< keypoint_number {
            for i in 0 ..< heatmap_w {
                for j in 0 ..< heatmap_h {
                    let index = k * (heatmap_w * heatmap_h) + i * (heatmap_h) + j
                    let confidence = heatmaps[index].doubleValue  // 置信度
                    guard confidence > 0 else { continue }  // 跳过置信度为 0 的点
                    if n_kpoints[k] == nil ||
                        (n_kpoints[k] != nil && n_kpoints[k]!.maxConfidence < confidence) {
                        // 如果 n_kpoints[k] 是空 或 置信度小于当前点
                        n_kpoints[k] = PredictedPoint(maxPoint: CGPoint(x: CGFloat(j), y: CGFloat(i)), maxConfidence: confidence)
                    }
                }
            }
        }
        
        // 坐标归一化
        // (0.0, 0.0) 到 (1.0, 1.0) 范围内
        n_kpoints = n_kpoints.map { kpoint -> PredictedPoint? in
            if let kp = kpoint {
                return PredictedPoint(maxPoint: CGPoint(x: (kp.maxPoint.x + 0.5) / CGFloat(heatmap_w),
                                                        y: (kp.maxPoint.y + 0.5) / CGFloat(heatmap_h)),
                                      maxConfidence: kp.maxConfidence)
            } else {
                return nil
            }
        }
        
        return n_kpoints
    }
    
    /// 将 Core ML 生成的 heatmap 转换为数组
    /// - Parameter heatmaps: 热图
    /// - Returns: 存储多通道热图各点置信度的数组
    func convertTo3DArray(from heatmaps: MLMultiArray) -> Array<Array<Double>> {
        guard heatmaps.shape.count >= 3 else {
            print("heatmap's shape is invalid. \(heatmaps.shape)")
            return []
        }
        let keypoint_number = heatmaps.shape[0].intValue
        let heatmap_w = heatmaps.shape[1].intValue
        let heatmap_h = heatmaps.shape[2].intValue
        
        var convertedHeatmap: Array<Array<Double>> = Array(repeating: Array(repeating: 0.0, count: heatmap_h), count: heatmap_w)
        
        for k in 0 ..< keypoint_number {
            for i in 0 ..< heatmap_w {
                for j in 0 ..< heatmap_h {
                    let index = k * (heatmap_w * heatmap_h) + i * (heatmap_h) + j
                    let confidence = heatmaps[index].doubleValue
                    guard confidence > 0 else { continue }  // 跳过置信度为 0 的点
                    convertedHeatmap[j][i] += confidence
                }
            }
        }
        
        convertedHeatmap = convertedHeatmap.map { row in
            return row.map { element in
                if element > 1.0 {
                    return 1.0
                } else if element < 0 {
                    return 0.0
                } else {
                    return element
                }
            }
        }
        
        return convertedHeatmap
    }
}
