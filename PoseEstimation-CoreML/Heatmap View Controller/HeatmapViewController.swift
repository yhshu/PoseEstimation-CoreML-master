//
//  HeatmapViewController.swift
//  PoseEstimation-CoreML
//
//

import UIKit
import Vision
import CoreMedia

class HeatmapViewController: UIViewController {

    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!            // 视频预览
    @IBOutlet weak var heatmapView: DrawingHeatmapView! // 生成的热图
    
    @IBOutlet weak var inferenceLabel: UILabel!         // 显示推断时间的标签
    @IBOutlet weak var etimeLabel: UILabel!             // 显示执行时间的标签
    @IBOutlet weak var fpsLabel: UILabel!               // 显示 FPS 的标签
    
    // MARK: - Performance Measurement Property
    private let performance = PerformanceMeasurement()
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!
    
    // MARK: - ML Properties
    // CoreML 模型
    typealias EstimationModel = model_cpm
    
    // 预处理和推断
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // 后处理
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置 CoreML 模型
        setUpModel()
        
        // 设置相机
        setUpCamera()
        
        // 设置性能测量的代理
        performance.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }
    
    // MARK: - Setup Core ML
    func setUpModel() {
        if let visionModel = try? VNCoreMLModel(for: EstimationModel().model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError()
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.videoCaptureDelegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // start video preview when setup is done
                self.videoCapture.start()
            }
        }
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
    
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // vision framework configures the input size of image following our model's input configuration automatically
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Poseprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        self.performance.label(with: "endInference")
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {

            // 将热图转换为 Array<Array<Double>>
            let heatmap3D = postProcessor.convertTo3DArray(from: heatmaps)
            
            DispatchQueue.main.sync {
                self.heatmapView.heatmap3D = heatmap3D
                
                // 测量结束
                self.performance.stop()
            }
        }
    }
}

// MARK: - VideoCaptureDelegate
extension HeatmapViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // 摄像头捕获的图像包含在 pixelBuffer 中
        if let pixelBuffer = pixelBuffer {
            // 开始测量
            self.performance.start()
            
            // 预测
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}


// MARK: - Performance Measurement Delegate
extension HeatmapViewController: PerformanceMeasurementDelegate {
    
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        self.inferenceLabel.text = "Inference: \(Int(inferenceTime * 1000.0)) mm"
        self.etimeLabel.text = "Execution: \(Int(executionTime * 1000.0)) mm"
        self.fpsLabel.text = "FPS: \(fps)"
    }
}
