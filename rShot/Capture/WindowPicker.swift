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
    /// 返回包含给定点（主屏左上原点）的最小普通窗口 rect；无则 nil
    static func window(at point: CGPoint) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID)
                as? [[String: Any]] else { return nil }

        let myPID = ProcessInfo.processInfo.processIdentifier
        var best: CGRect?

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

            // 取面积最小的（最上层精细命中的窗口），近似"鼠标正下方的窗口"
            if best == nil || rect.width * rect.height < best!.width * best!.height {
                best = rect
            }
        }
        return best
    }
}
