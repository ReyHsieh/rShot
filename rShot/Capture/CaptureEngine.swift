//
//  CaptureEngine.swift
//  rShot
//
//  截屏引擎：权限申请、整屏冻结（框选前抓取，避免遮罩污染截图）、选区裁剪
//
//  坐标系约定（重要）：
//  - SwiftUI DragGesture：主屏左上原点，y 向下，单位点
//  - CGWindowListCreateImage：同样是主屏左上原点、y 向下、单位点
//  → 两者天然一致，不需要任何翻转。CGImage 像素裁剪同样左上原点，只需乘 scale。
//

import ScreenCaptureKit
import AppKit
import CoreGraphics

final class CaptureEngine {
    static let shared = CaptureEngine()
    private init() {}

    enum Error: LocalizedError {
        case noDisplay
        case snapshotFailed(String)
        case permissionDenied
        var errorDescription: String? {
            switch self {
            case .noDisplay: return "找不到可用的显示器"
            case .snapshotFailed(let m): return "截图失败：\(m)"
            case .permissionDenied: return "屏幕录制权限被拒绝"
            }
        }
    }

    // MARK: - 冻结帧（框选前抓整屏）

    /// 框选开始前抓取的整屏画面。此刻覆盖层（遮罩/描边/工具栏）尚未显示，
    /// 画面干净；框选确认后从这帧裁剪，保证所见即所得。
    private(set) var frozenFrame: CGImage?
    /// 冻结帧的像素/点比例（Retina 为 2）
    private(set) var frozenScale: CGFloat = 2

    /// 主屏 rect（点，左上原点——数值上与 NSScreen.frame 相同）
    private var mainScreenRect: CGRect { NSScreen.main?.frame ?? .zero }

    /// 抓整屏（等待菜单收起动效 ~150ms），存为冻结帧
    func freezeScreen(completion: @escaping (Bool) -> Void) {
        let rect = mainScreenRect
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            usleep(150_000)  // 等待菜单栏下拉收起
            guard let cg = CGWindowListCreateImage(rect,
                                                    .optionOnScreenOnly,
                                                    kCGNullWindowID,
                                                    [.bestResolution]) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            self?.frozenFrame = cg
            self?.frozenScale = rect.width > 0 ? CGFloat(cg.width) / rect.width : 2
            DispatchQueue.main.async { completion(true) }
        }
    }

    /// 从冻结帧裁剪选区（sel：SwiftUI 左上原点，点单位）
    func cropFrozen(_ sel: CGRect) -> CGImage? {
        guard let frame = frozenFrame else { return nil }
        let s = frozenScale
        let px = CGRect(x: sel.minX * s, y: sel.minY * s,
                        width: sel.width * s, height: sel.height * s)
        let bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        return frame.cropping(to: px.intersection(bounds))
    }

    // MARK: - 权限

    func requestPermission(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false,
                                                                          onScreenWindowsOnly: false)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    // MARK: - 覆盖层（框选交互 / 原位标注）—— 唯一持有者

    private var overlayController: RegionOverlayController?

    func presentRegionOverlay() {
        dismissOverlay()
        let c = RegionOverlayController()
        c.show(frozen: frozenFrame)
        overlayController = c
    }

    /// 全屏截图：不框选，直接以冻结帧进入标注态
    func presentFullScreenAnnotating() {
        dismissOverlay()
        guard let cg = frozenFrame else { return }
        let rect = mainScreenRect
        let c = RegionOverlayController()
        c.show(frozen: cg)
        overlayController = c
        let img = NSImage(cgImage: cg, size: rect.size)
        OverlayState.shared.enterAnnotating(image: img, selection: rect)
    }

    func dismissOverlay() {
        overlayController?.close()
        overlayController = nil
        OverlayState.shared.reset()   // 彻底清状态（含 forOCR），防下次会话模式串扰
        OverlayKeyMonitor.remove()
    }
}
