//
//  AppState.swift
//  rShot
//
//  全局状态机：idle → capturing → annotating → done
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import Combine

final class AppState: ObservableObject {
    static let ocrWindowID = "rshot-ocr"
    /// 全局单例：覆盖窗（AppKit NSHostingView）与 SwiftUI App 共用同一个实例，
    /// 否则框选结果存进一个实例、编辑器读另一个实例，永远串不起来。
    static let shared = AppState()

    enum Phase: Equatable {
        case idle
        case capturing(CaptureMode)
        case annotating
        case ocr
    }

    enum CaptureMode {
        case region
        case fullScreen
        case ocr
    }

    @Published var phase: Phase = .idle
    @Published var editorImage: NSImage?       // 标注态使用的截图
    @Published var lastToast: String?          // 完成反馈（UI 由 ToastCenter 展示）

    @Published var lastOCRResult: OCRResult?

    private var toastCancellable: AnyCancellable?

    // MARK: - 入口动作（由菜单/快捷键触发）

    func startRegionCapture() {
        startWithFrozenScreen(mode: .region)
    }

    func startFullScreenCapture() {
        startWithFrozenScreen(mode: .fullScreen) { ok in
            if ok { CaptureEngine.shared.presentFullScreenAnnotating() }
        }
    }

    /// 统一入口：权限 → 冻结整屏 → 显示覆盖层。
    /// 互斥：同一时刻只允许一种截图模式（会话进行中忽略新触发）。
    private func startWithFrozenScreen(mode: CaptureMode,
                                       afterFreeze: ((Bool) -> Void)? = nil) {
        guard phase == .idle else { return }
        CaptureEngine.shared.requestPermission { [weak self] granted in
            guard granted else {
                self?.flashToast("未授权屏幕录制，请到系统设置开启")
                return
            }
            DispatchQueue.main.async {
                guard self?.phase == .idle else { return }   // 异步期间可能已有会话
                self?.phase = .capturing(mode)
                CaptureEngine.shared.freezeScreen { ok in
                    DispatchQueue.main.async {
                        guard ok else {
                            self?.flashToast("截图失败：无法捕获屏幕")
                            self?.phase = .idle
                            return
                        }
                        // 显式重置上次会话残留（含 forOCR），再进入新模式
                        OverlayState.shared.prepare(forOCR: mode == .ocr)
                        if mode != .fullScreen {
                            CaptureEngine.shared.presentRegionOverlay()
                        }
                        afterFreeze?(true)
                    }
                }
            }
        }
    }

    /// 打开设置窗口（自建 NSWindow，不依赖 responder chain）
    func openSettings() {
        SettingsWindowController.shared.show()
    }

    // MARK: - OCR 结果

    func openOCRWindow() {
        OCRPanelController.shared.show()
    }

    // MARK: - 完成反馈 toast

    func flashToast(_ text: String) {
        self.lastToast = text
        ToastCenter.shared.show(text)
        toastCancellable?.cancel()
        toastCancellable = Just(text)
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.lastToast = nil }
    }

    /// 用户在编辑器点「复制 / 完成」（是否写剪贴板受"自动复制"开关控制）
    func finishWithCopy(_ image: NSImage) {
        if AppSettings.shared.autoCopy {
            ClipboardService.shared.copyImage(image)
        }
        FileService.shared.saveIfConfigured(image)
        let copied = AppSettings.shared.autoCopy
        let toast: String
        if copied, let path = FileService.shared.lastSavedPath, AppSettings.shared.autoSaveToFolder {
            toast = "已复制到剪贴板 · \(path)"
        } else if copied {
            toast = "已复制到剪贴板"
        } else if let path = FileService.shared.lastSavedPath, AppSettings.shared.autoSaveToFolder {
            toast = "已保存至 \(path)"
        } else {
            toast = "已完成"
        }
        flashToast(toast)
        reset()
    }

    /// 用户点「取消」
    func cancelCapture() {
        reset()
        flashToast("已取消截图")
    }

    private func reset() {
        phase = .idle
        editorImage = nil
        OverlayState.shared.reset()
        CaptureEngine.shared.dismissOverlay()
    }
}
