//
//  gen_icon.swift — rShot App 图标生成器
//  运行：swift gen_icon.swift <输出路径.png>
//  绘制：macOS squircle 圆角 + 青蓝渐变 + 白色取景框 + 快门圆
//

import AppKit
import CoreGraphics

let size = 1024
let ctx = CGContext(data: nil, width: size, height: size,
                    bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 坐标系：左下原点；S = 1024
let S = CGFloat(size)

// ── 1. 背景：squircle 圆角矩形 + 垂直渐变（青蓝，设计系统 accent #0A84FF → 深蓝 #0060DF）
let radius: CGFloat = 232
let bgRect = CGRect(x: 0, y: 0, width: S, height: S)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius,
                    transform: nil)
let colors = [CGColor(red: 0.10, green: 0.55, blue: 1.00, alpha: 1),   // #1A8CFF 顶部亮
              CGColor(red: 0.00, green: 0.38, blue: 0.88, alpha: 1)] as CFArray  // #0061E0
let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: colors, locations: [0, 1])!
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
// 渐变方向：左上 → 右下
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: S * 0.2, y: S * 0.95),
                       end: CGPoint(x: S * 0.85, y: S * 0.05),
                       options: [])
ctx.restoreGState()

// 顶部内高光（模拟玻璃深度，设计系统 §2.5）
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let hl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
                             CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(hl, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: S * 0.55),
                       options: [])
ctx.restoreGState()

// ── 2. 取景框：四角 L 形粗线（白色、圆头）
let strokeW: CGFloat = 56
let armLen: CGFloat = 150
let margin: CGFloat = 264          // 内容区边距（图标内容约占 50-60%）
let inset = CGRect(x: margin, y: margin,
                   width: S - margin * 2, height: S - margin * 2)

ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(strokeW)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// 四角 L 形（逆时针从左下开始）
let pts: [(CGPoint, CGPoint, CGPoint)] = [
    // 左下角：竖上 + 横右
    (CGPoint(x: inset.minX, y: inset.minY),
     CGPoint(x: inset.minX, y: inset.minY + armLen),
     CGPoint(x: inset.minX, y: inset.minY)),
    // 简化：每角画两段线
]
// 直接画 8 段线段
let corners: [(CGPoint, CGPoint)] = [
    // 左下
    (CGPoint(x: inset.minX, y: inset.minY), CGPoint(x: inset.minX, y: inset.minY + armLen)),
    (CGPoint(x: inset.minX, y: inset.minY), CGPoint(x: inset.minX + armLen, y: inset.minY)),
    // 右下
    (CGPoint(x: inset.maxX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.minY + armLen)),
    (CGPoint(x: inset.maxX, y: inset.minY), CGPoint(x: inset.maxX - armLen, y: inset.minY)),
    // 左上
    (CGPoint(x: inset.minX, y: inset.maxY), CGPoint(x: inset.minX, y: inset.maxY - armLen)),
    (CGPoint(x: inset.minX, y: inset.maxY), CGPoint(x: inset.minX + armLen, y: inset.maxY)),
    // 右上
    (CGPoint(x: inset.maxX, y: inset.maxY), CGPoint(x: inset.maxX, y: inset.maxY - armLen)),
    (CGPoint(x: inset.maxX, y: inset.maxY), CGPoint(x: inset.maxX - armLen, y: inset.maxY)),
]
for (a, b) in corners {
    ctx.move(to: a)
    ctx.addLine(to: b)
}
ctx.strokePath()

// ── 3. 快门圆：中心白色圆环 + 实心圆点
let c = CGPoint(x: S / 2, y: S / 2)
let ringR: CGFloat = 128
ctx.setLineWidth(strokeW * 0.8)
ctx.strokeEllipse(in: CGRect(x: c.x - ringR, y: c.y - ringR,
                              width: ringR * 2, height: ringR * 2))
let dotR: CGFloat = 44
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: c.x - dotR, y: c.y - dotR,
                            width: dotR * 2, height: dotR * 2))

// ── 输出
let img = ctx.makeImage()!
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let url = URL(fileURLWithPath: outPath)
let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("written: \(outPath)")
