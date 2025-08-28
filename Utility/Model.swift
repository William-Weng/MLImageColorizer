//
//  Model.swift
//  Example
//
//  Created by William.Weng on 2025/8/28.
//

import UIKit
import CoreGraphics

/// [RGB色彩空間數值](https://zh.wikipedia.org/zh-tw/三原色光模式)
struct RGB {
    var red: Float      // 紅色 (0 ~ 255)
    var green: Float    // 綠色 (0 ~ 255)
    var blue: Float     // 藍色 (0 ~ 255)
}

/// [CIELAB色彩空間數值](https://zh.wikipedia.org/zh-tw/CIELAB色彩空间)
struct LAB {
    var l: Float        // 亮度 (Lightness)
    var a: Float        // 綠-紅 色相 (Green–Red opponent colors)
    var b: Float        // 藍-黃 色相 (Blue–Yellow opponent colors)
}

/// CIELAB色彩空間數值總計
struct LabValues {
    let l: [Float]      // 亮度 (Lightness)
    let a: [Float]      // 綠-紅 色相 (Green–Red opponent colors)
    let b: [Float]      // 藍-黃 色相 (Blue–Yellow opponent colors)
}
