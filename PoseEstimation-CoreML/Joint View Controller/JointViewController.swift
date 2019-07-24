//
//  ViewController.swift
//  PoseEstimation-CoreML
//
//

import UIKit
import Vision
import CoreMedia

class JointViewController: UIViewController {
    public typealias DetectObjectsCompletion = ([PredictedPoint?]?, Error?) -> Void // 函数类型
    
    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!            // 图像预览
    @IBOutlet weak var jointView: DrawingJointView!     // 生成的人体关节视图
    @IBOutlet weak var labelsTableView: UITableView!    // 显示关节结点标签的表格
    
    @IBOutlet weak var inferenceLabel: UILabel!         // 显示推断时间的标签
    @IBOutlet weak var etimeLabel: UILabel!             // 显示执行时间的标签
    @IBOutlet weak var fpsLabel: UILabel!               // 显示 FPS 的q标签
    
    // MARK: - Performance Measurement Property
    private let performanceMeasurement = PerformanceMeasurement()  // 用于性能测量的对象
    
    // MARK: - AV Property
    var videoCapture: VideoCapture!                     // 用于视频捕捉的对象
    
    // MARK: - ML Properties
    typealias EstimationModel = model_cpm               // CoreML 模型
    
    // MARK: 预处理与推断
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // 后处理
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()  // 热图后处理
    var mvfilters: [MovingAverageFilter] = []
    
    // 推断结果数据
    private var tableData: [PredictedPoint?] = []
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {  // 在控制器的视图载入到内存后调用
        super.viewDidLoad()
        
        // 设置 CoreML 模型
        setUpModel()
        
        // 设置相机
        setUpCamera()
        
        // 为底部的关节信息表格设置数据源
        // 包括预测的各关节的位置以及置信度
        labelsTableView.dataSource = self
        
        // 设置性能测量的代理
        // 性能测量包括推断时间、执行时间、FPS
        performanceMeasurement.delegate = self
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
            // VNCoreMLModel: 用于与 Vision 请求一同使用的 Core ML 模型的容器
            self.visionModel = visionModel
            
            // 使用 Core ML 模型处理图像的图像分析请求
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            
            // 可选设置，通知 Vision 算法如何缩放输入图像
            request?.imageCropAndScaleOption = .scaleFill // 按比例填充
        } else {         // Core ML 模型设置失败
            fatalError() // 无条件打印给定消息并停止执行
        }
    }
    
    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.videoCaptureDelegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            
            if success {
                // 在图层上添加预览视图
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                
                // 当设置完成后开始视频预览
                self.videoCapture.start()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }
    
    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

// MARK: - VideoCaptureDelegate
extension JointViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        // 摄像头捕获的图像包含在 pixelBuffer 中
        if let pixelBuffer = pixelBuffer {
            // 开始测量
            self.performanceMeasurement.start()
            
            // 进行预测
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension JointViewController {
    // MARK: - Inferencing
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        // Vision 框架根据我们模型的输入配置，自动配置图像的输入大小
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }
    
    // MARK: - Postprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        self.performanceMeasurement.label(with: "endInference")
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
            
            // 开始 heatmap 的后处理
            var predictedPoints = postProcessor.convertToPredictedPoints(from: heatmaps)
            
            // 移动平均过滤器
            if predictedPoints.count != mvfilters.count {
                mvfilters = predictedPoints.map { _ in MovingAverageFilter(limit: 3) }
            }
            for (predictedPoint, filter) in zip(predictedPoints, mvfilters) {
                // zip 创建由两个基础序列构建的一个由 pair 组成的序列
                filter.add(element: predictedPoint)
            }
            predictedPoints = mvfilters.map { $0.averagedValue() }
            
            // 展示结果，使用调度队列有序执行
            DispatchQueue.main.sync {
                // DispatchQueue.main 获取与当前进程的主线程关联的调度队列
                // sync 向队列提交一项工作，并在该块执行完成后返回
                
                // 画线
                self.jointView.bodyPoints = predictedPoints
                
                // 展示关键点的描述
                self.showKeyPointsDescription(with: predictedPoints)
                
                // 测量结束
                self.performanceMeasurement.stop()
            }
        } else {
            // 测量结束
            self.performanceMeasurement.stop()
        }
    }
    
    /// 展示关键点的描述
    /// - Parameter with: 预测点数组
    func showKeyPointsDescription(with n_kpoints: [PredictedPoint?]) {
        self.tableData = n_kpoints
        self.labelsTableView.reloadData()
    }
}

// MARK: - UITableView Data Source
extension JointViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count  // > 0 ? 1 : 0
    }
    
    /// 更新表格中的人体关节信息，包括预测的关节位置和置信度
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        cell.textLabel?.text = Constant.pointLabels[indexPath.row]
        if let body_point = tableData[indexPath.row] {
            let pointText: String = "\(String(format: "%.3f", body_point.maxPoint.x)), \(String(format: "%.3f", body_point.maxPoint.y))"  // 位置
            cell.detailTextLabel?.text = "(\(pointText)), [\(String(format: "%.3f", body_point.maxConfidence))]"  // 置信度
        } else {
            cell.detailTextLabel?.text = "N/A"
        }
        return cell
    }
}

// MARK: - Performance Measurement Delegate
extension JointViewController: PerformanceMeasurementDelegate {
    
    /// 更新测量数据，包括推断时间、执行时间、FPS
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        self.inferenceLabel.text = "Inference: \(Int(inferenceTime * 1000.0)) mm" // 更新推断时间
        self.etimeLabel.text = "Execution: \(Int(executionTime * 1000.0)) mm"     // 更新执行时间
        self.fpsLabel.text = "FPS: \(fps)"                                        // 更新 FPS
    }
}
