//
//  Constant.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit

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
