//
//  ImageColorizer.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//
//
//

import UIKit
import CoreML

final class ImageColorizer {

    func colorize(image inputImage: UIImage, completion: @escaping (Result<UIImage, Error>) -> Void)  {
        
        DispatchQueue.global().async {
            let result = self.colorize(image: inputImage)
            DispatchQueue.main.async { completion(result) }
        }
    }
}

/// MARK: 常數
private extension ImageColorizer {
    
    struct Constants {
        static let inputDimension = 256
        static let inputSize = CGSize(width: inputDimension, height: inputDimension)
        static let coremlInputShape = [1, 1, NSNumber(value: Constants.inputDimension), NSNumber(value: Constants.inputDimension)]
    }
    
    enum ColorizerError: Error {
        case preprocessFailure
        case postprocessFailure
    }
}

/// MARK: - 主函式
private extension ImageColorizer {
    
    /// [圖片上色](https://www.onswiftwings.com/posts/image-colorization-coreml/)
    /// - Parameter inputImage: [UIImage](https://github.com/Vadbeg/colorization-coreml)
    /// - Returns: [Result<UIImage, Error>](https://github.com/sgl0v/ImageColorizer)
    func colorize(image inputImage: UIImage) -> Result<UIImage, Error> {
        do {
            let inputImageLab = try preProcess(inputImage: inputImage)
            let input = try coloriserInput(from: inputImageLab)
            let output = try CoremlColorizer(configuration: MLModelConfiguration()).prediction(input: input)
            let outputImageLab = imageLab(from: output, inputImageLab: inputImageLab)
            let resultImage = try postProcess(inputImage: inputImage, outputLAB: outputImageLab)
            return .success(resultImage)
        } catch {
            return .failure(error)
        }
    }
}

/// MARK: - 小工具
private extension ImageColorizer {

    /// 將 Lab 色彩空間數據轉換為 Core ML 模型輸入格式 (由亮度l => 預測出a和b通道)
    /// - Parameter imageLab: Lab 色彩空間的圖像數據
    /// - Returns: Core ML 模型的輸入數據
    func coloriserInput(from imageLab: LabValues) throws -> CoremlColorizerInput {
        
        // 創建一個 MLMultiArray 來儲存模型的輸入數據
        let inputArray = try MLMultiArray(shape: Constants.coremlInputShape, dataType: MLMultiArrayDataType.float32)
        
        // 遍歷圖像的 L 通道（亮度），並將其填入 MLMultiArray
        imageLab.l.enumerated().forEach({ (idx, value) in
            let inputIndex = [NSNumber(value: 0), NSNumber(value: 0), NSNumber(value: idx / Constants.inputDimension), NSNumber(value: idx % Constants.inputDimension)]
            inputArray[inputIndex] = value as NSNumber
        })
        
        // 返回包含輸入數據的 coremlColorizerInput 物件
        return CoremlColorizerInput(input1: inputArray)
    }

    /// 從 Core ML 模型輸出中提取 a 和 b 色彩通道，並與原始 L 通道結合 (原始圖片亮度 + 預測出的顏色值)
    /// - Parameters:
    ///   - colorizerOutput: Core ML 模型的輸出
    ///   - inputImageLab: 包含原始 L 通道的 Lab 數據
    /// - Returns: 包含 L、a、b 三個通道的完整 Lab 數據
    func imageLab(from colorizerOutput: CoremlColorizerOutput, inputImageLab: LabValues) -> LabValues {
        
        var a = [Float]()
        var b = [Float]()
        
        for idx in 0..<Constants.inputDimension * Constants.inputDimension {
            
            let aIdx = [NSNumber(value: 0), NSNumber(value: 0), NSNumber(value: idx / Constants.inputDimension), NSNumber(value: idx % Constants.inputDimension)]
            let bIdx = [NSNumber(value: 0), NSNumber(value: 1), NSNumber(value: idx / Constants.inputDimension), NSNumber(value: idx % Constants.inputDimension)]
            
            a.append(colorizerOutput._796[aIdx].floatValue)
            b.append(colorizerOutput._796[bIdx].floatValue)
        }
        
        return LabValues(l: inputImageLab.l, a: a, b: b)
    }
    
    /// 先轉成圖片正規化後的LAB值 => (256 x 256)
    /// - Parameter inputImage: UIImage
    /// - Returns: LabValues
    func preProcess(inputImage: UIImage) throws -> LabValues {
        
        guard let normalizeImage = inputImage._normalize(with: Constants.inputSize, bitsPerComponent: 8, bitsPerPixel: 32),
              let lab = LCM2Utility.shared.labValues(cgImage: normalizeImage.cgImage)
        else {
            throw ColorizerError.preprocessFailure
        }
        
        return LabValues(l: lab[0], a: lab[1], b: lab[2])
    }
    
    /// 執行上色的功能
    /// - Parameters:
    ///   - inputImage: UIImage
    ///   - outputLAB: LabValues
    /// - Returns: UIImage
    func postProcess(inputImage: UIImage, outputLAB: LabValues) throws -> UIImage {
        
        let image = LCM2Utility.shared.image(fromLabChannels: outputLAB.l, a: outputLAB.a, b: outputLAB.b, size: Constants.inputSize)
        
        guard let resultImage = image?._normalize(with: inputImage.size, bitsPerComponent: 8, bitsPerPixel: 32),
              let originalImage = inputImage._normalize(with: inputImage.size, bitsPerComponent: 8, bitsPerPixel: 32),
              let resultImageLab = LCM2Utility.shared.labValues(cgImage: resultImage.cgImage),
              let originalImageLab = LCM2Utility.shared.labValues(cgImage:originalImage.cgImage)
        else {
            throw ColorizerError.preprocessFailure
        }
        
        return LCM2Utility.shared.image(fromLabChannels: originalImageLab[0], a: resultImageLab[1], b: resultImageLab[2], size: inputImage.size)!
    }
}

