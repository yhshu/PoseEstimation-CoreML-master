//
//  VideoCapture.swift
//
//

import UIKit
import AVFoundation
import CoreVideo

public protocol VideoCaptureDelegate: class {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

public class VideoCapture: NSObject {
    public var previewLayer: AVCaptureVideoPreviewLayer?        // 预览层
    public weak var videoCaptureDelegate: VideoCaptureDelegate? // 视频捕捉代理
    public var fps = 15
    
    let captureSession = AVCaptureSession()      // 管理捕获活动并协调从输入设备到捕获输出的数据流的对象
    let videoOutput = AVCaptureVideoDataOutput() // 捕获输出，用于记录视频并提供对视频帧的访问以进行处理
    let queue = DispatchQueue(label: "com.shuyiheng.camera-queue") // 在应用程序的主线程或后台线程上串行或同时管理任务执行的对象
    
    var lastTimestamp = CMTime()  // CMTime() 表示时间值的结构，例如时间戳或持续时间
    
    /// 设置
    /// - Parameter sessionPreset: 表示输出的质量等级或比特率
    /// - Parameter completion: 逃逸闭包，在函数执行完后被调用
    public func setUp(sessionPreset: AVCaptureSession.Preset = .vga640x480,
                      completion: @escaping (Bool) -> Void) {
        self.setUpCamera(sessionPreset: sessionPreset, completion: { success in
            completion(success)
        })
    }
    
    /// 设置摄像头
    /// - Parameter sessionPreset: 表示输出的质量等级或比特率
    /// - Parameter completion: 逃逸闭包，在函数执行完后被调用
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, completion: @escaping (_ success: Bool) -> Void) {
        
        captureSession.beginConfiguration()  // 以原子方式进行的一组配置更改的开始
        captureSession.sessionPreset = sessionPreset // 设置质量等级或比特率
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: .back)
            // 参数：请求捕获的设备类型，请求捕获的媒体类型，捕获设备相对于系统硬件（正面或背面）请求的位置
            // 返回：指定参数条件下的系统默认设备，没有可用设备返回 nil
        else {
            print("Error: no video devices available")
            return
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return
        }
        // AVCaptureDeviceInput: 捕获输入，用于将捕获设备中的媒体提供给捕获会话
        
        if captureSession.canAddInput(videoInput) {  // 判断会话是否可以添加给定输入
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) // 核心动画层，用于显示捕获的视频
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect // 设置视频在播放器视图边界内的显示方式：播放器应保留视频的宽高比，并使视频适合图层的范围
        previewLayer.connection?.videoOrientation = .portrait  // 视频方向：垂直定向
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]  // 缓冲使用的像素格式类型
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true  // 视频帧迟到时被丢弃
        videoOutput.setSampleBufferDelegate(self, queue: queue)  // 设置示例缓冲区委托以及应在其上调用回调的队列
        if captureSession.canAddOutput(videoOutput) {  // 判断会话是否可以添加给定输出
            captureSession.addOutput(videoOutput)
        }
        
        // 视频方向：纵向
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        captureSession.commitConfiguration()  // 提交一组配置修改
        
        let success = true
        completion(success)
    }
    
    public func start() {
        if !captureSession.isRunning {  // 判断是否尚未开始运行
            captureSession.startRunning()
        }
    }
    
    public func stop() {
        if captureSession.isRunning {   // 判断是否仍在运行
            captureSession.stopRunning()
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 因为降低捕捉设备的 FPS 在预览中观感不好，
        // 此处使用全速捕捉，但只在所需的帧速率上调用 delegate；
        // 即不是在预览中的每一帧都调用了 delegate
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) // 返回所有样本中最早的显示时间戳
        let deltaTime = timestamp - lastTimestamp                            // 时间差
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)) {
            // CMTimeMake 使用值和时间刻度生成有效的 CMTime，Epoch 隐含为0
            lastTimestamp = timestamp                                        // 更新时间戳
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)     // 获取图像缓存
            videoCaptureDelegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    }
}

