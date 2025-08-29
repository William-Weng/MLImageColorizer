//
//  ImageColorizer.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//
// https://www.onswiftwings.com/posts/image-colorization-coreml/
// https://github.com/sgl0v/ImageColorizer
// https://github.com/Vadbeg/colorization-coreml

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

// MARK: Private

extension ImageColorizer {
    
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

private extension ImageColorizer {

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

struct LCM2Utility {
    
    static let shared = LCM2Utility()
    
    private init() {}
    
    let TYPE_Lab_FLT: UInt32 = 4849692
    let TYPE_RGB_FLT: UInt32 = 4456476
    
    enum ColorSpaceTransformType {

        case lab2rgb
        case rgb2lab
        
        /// icc設定文件路徑
        /// - Parameter bundle: Bundle
        /// - Returns: String?
        func profilePath(with bundle: Bundle) -> String? {
            switch self {
            case .lab2rgb: bundle.path(forResource: "sRGB_ICC_v4_Appearance", ofType: "icc")
            case .rgb2lab: bundle.path(forResource: "sRGB_v4_ICC_preference", ofType: "icc")
            }
        }
    }
    
    /// RGB => LAB (色彩空間)
    /// - Parameters:
    ///   - transform: cmsHTRANSFORM
    ///   - rgbColor: RGB
    /// - Returns: RGB
    func rgb2lab(transform: cmsHTRANSFORM, rgbColor: RGB) -> LAB {

        var labValues: [Float] = [0, 0, 0]
        var rgbValues: [Float] = [rgbColor.red / 255, rgbColor.green / 255, rgbColor.blue / 255]
        
        cmsDoTransform(transform, &rgbValues, &labValues, 1)

        return LAB(l: labValues[0], a: labValues[1], b: labValues[2])
    }
    
    /// LAB => RGB (色彩空間)
    /// - Parameters:
    ///   - transform: cmsHTRANSFORM
    ///   - labColor: Lab
    /// - Returns: RGB
    func lab2rgb(transform: cmsHTRANSFORM, labColor: LAB) -> RGB {
        
        var rgbValues: [Float] = [0, 0, 0]
        var labValues: [Float] = [labColor.l, labColor.a, labColor.b]
        
        cmsDoTransform(transform, &labValues, &rgbValues, 1)
        
        return RGB(red: rgbValues[0] * 255.0, green: rgbValues[1] * 255.0, blue: rgbValues[2] * 255.0)
    }
    
    /// 色彩空間轉換工具 (LAB <=> GRB)
    /// - Parameters:
    ///   - type: ColorSpaceTransformType
    ///   - bundle: Bundle
    /// - Returns: cmsHTRANSFORM?
    func colorSpaceTransform(type: ColorSpaceTransformType, bundle: Bundle) -> cmsHTRANSFORM? {
        
        guard let profilePath = type.profilePath(with: bundle) else { return nil }
        
        let rgbProfile = cmsOpenProfileFromFile(profilePath, "r")
        let labProfile = cmsCreateLab4Profile(nil)
        let transform: cmsHTRANSFORM?
        
        switch type {
        case .lab2rgb: transform = cmsCreateTransform(labProfile, TYPE_Lab_FLT, rgbProfile, TYPE_RGB_FLT, cmsUInt32Number(INTENT_PERCEPTUAL), 0)
        case .rgb2lab: transform = cmsCreateTransform(rgbProfile, TYPE_RGB_FLT, labProfile, TYPE_Lab_FLT, cmsUInt32Number(INTENT_PERCEPTUAL), 0)
        }
                
        cmsCloseProfile(labProfile)
        cmsCloseProfile(rgbProfile)
        
        return transform
    }
    
    /// 取得CGImaged的LAB數值
    /// - Returns: [[Float]]?
    func labValues(cgImage: CGImage?) -> [[Float]]? {
        
        guard let cgImage = cgImage,
              let data = cgImage.dataProvider?.data,
              let pixels = CFDataGetBytePtr(data),
              let transform = colorSpaceTransform(type: .rgb2lab, bundle: .main)
        else {
            return nil
        }

        var resL: [Float] = []
        var resA: [Float] = []
        var resB: [Float] = []

        let step = cgImage.bitsPerPixel / 8
        let length = CFDataGetLength(data)
        
        for i in stride(from: 0, to: length, by: step) {
            
            let rgb = RGB(red: Float(pixels[i]), green: Float(pixels[i + 1]), blue: Float(pixels[i + 2]))
            let lab = rgb2lab(transform: transform, rgbColor: rgb)
            
            resL.append(lab.l)
            resA.append(lab.a)
            resB.append(lab.b)
        }
        
        return [resL, resA, resB]
    }
    
    /// 從LAB數據 => RGB圖片
    /// - Parameters:
    ///   - l: [Float]
    ///   - a: [Float]
    ///   - b: [Float]
    ///   - size: CGSize
    /// - Returns: UIImage?
    func image(fromLabChannels l: [Float], a: [Float], b: [Float], size: CGSize) -> UIImage? {
        
        let width = Int(size.width)
        let height = Int(size.height)
        let pixelSize = width * height
        let alpha: Float = 1.0
        var labaData = [Float]()

        guard l.count == pixelSize,
              a.count == pixelSize,
              b.count == pixelSize,
              let transform = colorSpaceTransform(type: .lab2rgb, bundle: .main)
        else {
            return nil
        }
        
        labaData.reserveCapacity(width * height * 4)
        
        for i in 0..<(width * height) {
            
            let labColor = LAB(l: l[i], a: a[i], b: b[i])
            let rgb = lab2rgb(transform: transform, labColor: labColor);
            
            labaData.append(rgb.red / 255.0)
            labaData.append(rgb.green / 255.0)
            labaData.append(rgb.blue / 255.0)
            labaData.append(alpha)
        }
        
        let ciImage = labaData.withUnsafeBufferPointer {
            CIImage(bitmapData: Data(buffer: $0), bytesPerRow: width * 4 * MemoryLayout<Float>.size, size: size, format: .RGBAf, colorSpace: CGColorSpaceCreateDeviceRGB())
        }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
