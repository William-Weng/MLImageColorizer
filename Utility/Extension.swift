//
//  Extension.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit
import CoreGraphics

class Constant {
    
    /// ColorSpace類型
    enum CGColorSpaceType {
        
        case Gray
        case RGB
        case CMYK
        
        /// 取得其值
        /// - Returns: CGColorSpace
        func value() -> CGColorSpace {
            
            switch self {
            case .Gray: return CGColorSpaceCreateDeviceGray()
            case .RGB: return CGColorSpaceCreateDeviceRGB()
            case .CMYK: return CGColorSpaceCreateDeviceCMYK()
            }
        }
    }
    
    /// ColorComponent類型
    enum ColorComponentType {

        case bitmap                 // 點陣圖 (2^1色)
        case indexedColor2          // 索引顏色 (2^2色)
        case indexedColor4          // 索引顏色 (2^4色)
        case trueColor              // 真彩色 (2^8色)
        case deepColor              // 深色 (2^16色)
        case floatingPointColor     // 浮點數顏色 (2^32色)
        case custom(_ n: Int)       // 自訂 (2^n色)
        
        /// 取色盤數值
        /// - Returns: Int
        func value() -> Int {
            switch self {
            case .bitmap: return 1
            case .indexedColor2: return 2
            case .indexedColor4: return 4
            case .trueColor: return 8
            case .deepColor: return 16
            case .floatingPointColor: return 32
            case .custom(let n): return n
            }
        }
    }
}

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
