//
//  WindowPicker.swift
//  rShot
//
//  窗口截图识别（S-03）：查询鼠标位置下最上层可用窗口的屏幕 rect。
//  CGWindowListCopyWindowInfo 的 kCGWindowBounds 是主屏左上原点点坐标，
//  与 SwiftUI DragGesture 坐标系一致，可直接使用。
//

import AppKit
import CoreGraphics

enum WindowPicker {
    /// 返回包含给定点（主屏左上原点）的最上层可见普通窗口 rect；无则 nil。
    /// CGWindowListCopyWindowInfo 返回顺序即 z 序（前 = 上层），
    /// 取第一个命中 → 被遮挡的窗口不会被选中（符合直觉）。
    static func window(at point: CGPoint) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]] else { return nil }

        let myPID = ProcessInfo.processInfo.processIdentifier

        for info in infos {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != myPID,                       // 排除自己（覆盖层）
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,                              // 仅普通窗口层
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            guard rect.width > 60, rect.height > 60 else { continue }   // 排除小浮窗
            guard rect.contains(point) else { continue }

            return rect   // z 序第一个命中 = 最上层可见窗口
        }
        return nil
    }
}
