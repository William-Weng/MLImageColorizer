//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit
import CoreGraphics

// MARK: - CGContext (static function)
extension CGContext {
    
    /// 建立Context
    /// - Parameters:
    ///   - info: UInt32
    ///   - size: CGSize
    ///   - pixelData: UnsafeMutableRawPointer?
    ///   - bitsPerComponent: Int
    ///   - bytesPerRow: Int
    ///   - colorSpace: CGColorSpace
    /// - Returns: CGContext?
    static func _build(with info: UInt32, size: CGSize, pixelData: UnsafeMutableRawPointer?, bitsPerComponent: Int, bytesPerRow: Int, colorSpace: CGColorSpace) -> CGContext? {
        let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: info)
        return context
    }
}

extension CGImage {
    
    /// 轉換圖片顏色組成 (1024色 => 256色)
    /// - Parameters:
    ///   - bitsPerComponent: 每一個顏色組件 =>（R, G, B, A）各用 8-bits 表示 (256色)
    ///   - bitsPerPixel: 顏色組成 =>R(8) + G(8) + B(8) + A(8) = 32-bits
    ///   - bytesPerRow: 一列有幾bytes
    func _convertBitsPerComponent(_ bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int? = nil) -> CGImage? {
        
        let bytesPerRow = bytesPerRow ?? width * bitsPerPixel / 8
        let colorSpace = colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue
        let rect = CGRect(x: 0, y: 0, width: width, height: height)

        guard let context = CGContext._build(with: bitmapInfo, size: rect.size, pixelData: nil, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, colorSpace: colorSpace) else { return nil }
        
        context.draw(self, in: rect)
        return context.makeImage()
    }
}

// MARK: - UIGraphicsImageRendererFormat (function)
extension UIGraphicsImageRendererFormat {
    
    /// 設定比例
    /// - Parameter scale: 比例
    /// - Returns: Self
    func _scale(_ scale: CGFloat) -> Self {
        self.scale = scale
        return self
    }
    
    /// 透明度開關
    /// - Parameter opaque: Bool
    /// - Returns: Self
    func _opaque(_ opaque: Bool) -> Self {
        self.opaque = opaque
        return self
    }
}

// MARK: - UIImage (function)
extension UIImage {

    /// 改變圖片大小
    /// - Returns: UIImage
    /// - Parameters:
    ///   - size: 要改變的尺寸
    ///   - format: UIGraphicsImageRendererFormat
    func _resized(for size: CGSize, format: UIGraphicsImageRendererFormat) -> UIImage {
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let resizeImage = renderer.image { (context) in draw(in: renderer.format.bounds) }
        
        return resizeImage
    }
    
    /// 圖片標準化 (大小 / 色深)
    /// - Parameters:
    ///   - size: 大小
    ///   - bitsPerComponent: 每一個顏色組件 =>（R, G, B, A）各用 8 位表示 (256色)
    ///   - bitsPerPixel: 顏色組成 =>R(8) + G(8) + B(8) + A(8) = 32
    ///   - bytesPerRow: 一列有幾bytes
    /// - Returns: UIImage?
    func _normalize(with size: CGSize, bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int? = nil) -> UIImage? {
        
        let format = UIGraphicsImageRendererFormat.default()._scale(1.0)
        let resizedImage = self._resized(for: size, format: format)
        
        guard let cgimage = resizedImage.cgImage?._convertBitsPerComponent(bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow) else { return nil }
        
        return UIImage(cgImage: cgimage)
    }
}
