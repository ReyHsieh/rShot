//
//  MosaicRenderer.swift
//  rShot
//
//  真·马赛克（像素化）：对底图对应区域缩小 → 无插值放大 → 像素块效果。
//

import AppKit
import CoreGraphics

enum MosaicRenderer {
    /// 从底图取 frame（画布点坐标）区域，生成像素化图像。
    /// - Parameters:
    ///   - source: 底图 CGImage（像素尺寸 = canvas × scale）
    ///   - frame: 马赛克区域（画布点坐标，左上原点）
    ///   - canvas: 画布逻辑尺寸（点）
    ///   - blockSize: 每个像素块的边长（点）
    /// - Returns: NSImage（size = frame.size 点，内容为像素化结果）
    static func pixelated(from source: CGImage,
                          frame: CGRect,
                          canvas: CGSize,
                          blockSize: CGFloat = 16) -> NSImage? {
        guard canvas.width > 0, canvas.height > 0,
              frame.width > 1, frame.height > 1 else { return nil }

        let scaleX = CGFloat(source.width) / canvas.width
        let scaleY = CGFloat(source.height) / canvas.height
        // CGImage 像素坐标同为左上原点，直接缩放
        let cropPx = CGRect(x: (frame.minX * scaleX).rounded(.down),
                             y: (frame.minY * scaleY).rounded(.down),
                             width: (frame.width * scaleX).rounded(.up),
                             height: (frame.height * scaleY).rounded(.up))
        let bounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        guard let crop = source.cropping(to: cropPx.intersection(bounds)) else { return nil }

        // 1) 缩小：每个块收敛为 1 像素
        let smallW = max(1, Int(frame.width / blockSize))
        let smallH = max(1, Int(frame.height / blockSize))
        guard let smallCtx = CGContext(data: nil, width: smallW, height: smallH,
                                        bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        smallCtx.interpolationQuality = .medium
        smallCtx.draw(crop, in: CGRect(x: 0, y: 0, width: smallW, height: smallH))
        guard let small = smallCtx.makeImage() else { return nil }

        // 2) 放大：无插值 → 像素块。输出尺寸取裁剪像素尺寸（Retina 细节保留）
        let outW = crop.width, outH = crop.height
        guard let outCtx = CGContext(data: nil, width: outW, height: outH,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        outCtx.interpolationQuality = .none
        outCtx.draw(small, in: CGRect(x: 0, y: 0, width: outW, height: outH))
        guard let out = outCtx.makeImage() else { return nil }

        let img = NSImage(cgImage: out, size: frame.size)
        return img
    }
}
