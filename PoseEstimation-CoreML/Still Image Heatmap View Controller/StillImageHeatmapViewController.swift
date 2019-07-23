//
//  StillImageHeatmapViewController.swift
//  PoseEstimation-CoreML
//
//

import UIKit
import Photos
import Vision
import CoreMedia

class StillImageHeatmapViewController: UIViewController {
    
    // MARK: - UI Properties
    @IBOutlet weak var mainImageView: UIImageView!      // 原图
    @IBOutlet weak var heatmapView: DrawingHeatmapView! // 生成的热图
    @IBOutlet weak var guideLabel: UILabel!             // 含有提示信息的标签
    
    let galleryPicker = UIImagePickerController()
    
    // MARK: - ML Properties
    // CoreML 模型
    typealias EstimationModel = model_cpm
    
    // 预处理和推断
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    
    // 后处理
    var postProcessor: HeatmapPostProcessor = HeatmapPostProcessor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置 CoreML 模型
        setUpModel()
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
    
    @IBAction func tapPhotoLibraryItem(_ sender: Any) {
        openPicker()
    }
    
    // 打开图像选择器，在照片图库中选择图片
    func openPicker() {
        galleryPicker.sourceType = .photoLibrary
        galleryPicker.delegate = self
        present(galleryPicker, animated: true)
    }
}

// MARK: - UINavigationControllerDelegate & UIImagePickerControllerDelegate
extension StillImageHeatmapViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
        print("canceled")
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            mainImageView.image = image
            guideLabel.alpha = 0
            predictUsingVision(uiImage: image)
        }
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - CoreML
extension StillImageHeatmapViewController {
    // MARK: - Inferencing
    func predictUsingVision(uiImage: UIImage) {
        guard let request = request, let cgImage = uiImage.cgImage else { fatalError() }
        // 视觉框架根据我们模型的输入配置，自动配置图像的输入大小
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: uiImage.convertImageOrientation())
        try? handler.perform([request])
    }
    
    // MARK: - Poseprocessing
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
            
            // 将热图转换为 Double 型的二维数组 Array<Array<Double>>
            let heatmap3D = postProcessor.convertTo3DArray(from: heatmaps)

            // 必须运行在主线程
            self.heatmapView.heatmap3D = heatmap3D
            
        }
    }
}

extension UIImage {
    func convertImageOrientation() -> CGImagePropertyOrientation  {
        let cgiOrientations : [ CGImagePropertyOrientation ] = [
            .up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored
        ]
        return cgiOrientations[imageOrientation.rawValue]
    }
}
