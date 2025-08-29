//
//  LCM2Utility.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit
import CoreGraphics

/// MARK: - littlecms的工具集
struct LCM2Utility {
    
    static let shared = LCM2Utility()
    
    private init() {}
    
    private let TYPE_Lab_FLT: UInt32 = 4849692
    private let TYPE_RGB_FLT: UInt32 = 4456476
    
    /// 色域轉換類型
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
}

// MARK: - 工具
extension LCM2Utility {
    
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
