//
//  CaptureOverlay.swift  (RegionOverlayController + OverlayRootView)
//  rShot
//
//  全屏覆盖层：框选态 → 标注态（iShot 式原位标注，不弹独立窗口）
//  对应 OD screen-capture.html + screen-editor.html
//
//  坐标系：全程 SwiftUI 左上原点（DragGesture 原生）。
//  CGWindowListCreateImage 同为左上原点（窗口服务器坐标系），裁剪冻结帧时乘 scale 即可，无翻转。
//

import SwiftUI
import AppKit

/// borderless NSPanel 默认不能成为 key window，文本输入需要键盘焦点 → 子类放开
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RegionOverlayController {
    private let panel: KeyablePanel

    init() {
        guard let screen = NSScreen.main else { fatalError("no screen") }
        let rect = screen.frame
        panel = KeyablePanel(contentRect: rect,
                             styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // 参考 macshot 的 overlay 窗口管理：
        // - 接收鼠标移动事件（SwiftUI gesture/DragGesture 依赖）
        // - 显式管理点击穿透：显示时接收，收起时穿透（防"幽灵面板"吞点击）
        // - 无动画（避免 Reduce Motion 下的缩放残影）
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true

        let hosting = NSHostingView(rootView:
            OverlayRootView()
                .environmentObject(AppState.shared)
        )
        hosting.frame = rect
        panel.contentView = hosting
    }

    func show(frozen: CGImage?) {
        _ = frozen  // 冻结帧由 CaptureEngine 持有；覆盖层期间实时屏幕即所见
        panel.ignoresMouseEvents = false
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.ignoresMouseEvents = true
        panel.orderOut(nil)
    }
}

/// 键盘监听单例 holder：防止视图反复 onAppear 累加 local monitor 造成泄漏/重复触发
enum OverlayKeyMonitor {
    private static var monitor: Any?

    static func install(_ handler: @escaping (NSEvent) -> NSEvent) {
        remove()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: handler)
    }

    static func remove() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}

/// 覆盖层共享状态（框选态 ↔ 标注态切换）
final class OverlayState: ObservableObject {
    static let shared = OverlayState()
    enum Mode { case selecting, annotating }

    @Published var mode: Mode = .selecting
    @Published var capturedImage: NSImage?       // 标注态显示的截图（点尺寸 = 选区尺寸）
    @Published var selection: CGRect = .zero      // 选区（左上原点，点单位）
    /// OCR 模式：框选确认后直接识别，不进标注态
    var forOCR: Bool = false

    func enterAnnotating(image: NSImage, selection: CGRect) {
        capturedImage = image
        self.selection = selection
        mode = .annotating
    }

    /// 新会话开始前显式重置全部状态（含 forOCR），杜绝上一次会话的模式残留
    func prepare(forOCR: Bool) {
        reset()
        self.forOCR = forOCR
    }

    func reset() {
        mode = .selecting
        capturedImage = nil
        selection = .zero
        forOCR = false
    }
}

/// 覆盖层根视图：根据模式分发到框选视图 / 标注视图
struct OverlayRootView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var overlay = OverlayState.shared

    var body: some View {
        ZStack {
            switch overlay.mode {
            case .selecting:
                RegionSelectorView()
            case .annotating:
                if let img = overlay.capturedImage {
                    InPlaceEditorView(image: img, selection: overlay.selection)
                }
            }
        }
        .background(Color.clear)
    }
}

// MARK: - 框选态视图

/// 框选视图：全屏暗遮罩 + 拖拽选区 + 尺寸标签 + 悬停窗口高亮（单击截整窗）
struct RegionSelectorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var overlay = OverlayState.shared

    @State private var start: CGPoint? = nil
    @State private var current: CGPoint? = nil
    @State private var dragging = false
    /// 悬停识别到的窗口 rect（主屏左上原点，点坐标）；开始拖拽即清空
    @State private var hoverWindowRect: CGRect? = nil

    private var selection: CGRect? {
        guard let s = start, let c = current else { return nil }
        return CGRect(x: min(s.x, c.x), y: min(s.y, c.y),
                      width: abs(c.x - s.x), height: abs(c.y - s.y))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZStack {
                    Color.black.opacity(0.55)
                    if let sel = selection {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: sel.width, height: sel.height)
                            .position(x: sel.midX, y: sel.midY)
                            .blendMode(.destinationOut)
                    }
                    // 悬停窗口挖空（单击可截整窗）
                    if let w = hoverWindowRect {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: w.width, height: w.height)
                            .position(x: w.midX, y: w.midY)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                if let sel = selection {
                    SelectionChrome(selection: sel, containerSize: geo.size)
                        .allowsHitTesting(false)
                }

                // 悬停窗口描边高亮
                if let w = hoverWindowRect {
                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: w.width, height: w.height)
                        .position(x: w.midX, y: w.midY)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HintPill(text: "拖拽框选区域 · 单击截取窗口 · ESC 取消")
                        .padding(.bottom, 24)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !dragging {
                            start = v.startLocation
                            dragging = true
                            // 不在此清 hover：单击也会进这里；位移超阈值才切自定义区域
                        }
                        current = v.location
                        if let s = start,
                           hypot(v.location.x - s.x, v.location.y - s.y) > 4 {
                            hoverWindowRect = nil   // 真正开始拖拽 → 放弃窗口模式
                        }
                    }
                    .onEnded { v in
                        dragging = false
                        let moved = hypot(v.location.x - v.startLocation.x,
                                          v.location.y - v.startLocation.y)
                        if moved < 4, let w = hoverWindowRect {
                            // 单击：截取悬停窗口（clamp 到屏幕内）
                            let clamped = w.intersection(CGRect(x: 0, y: 0,
                                                                 width: geo.size.width,
                                                                 height: geo.size.height))
                            if clamped.width > 4, clamped.height > 4 {
                                confirmSelection(clamped)
                            }
                            start = nil; current = nil
                        } else if let sel = selection, sel.width > 4, sel.height > 4 {
                            confirmSelection(sel)
                        } else {
                            start = nil; current = nil
                        }
                    }
            )
        }
        .background(Color.clear)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if !dragging { hoverWindowRect = WindowPicker.window(at: location) }
            case .ended:
                if !dragging { hoverWindowRect = nil }
            }
        }
        .onAppear {
            OverlayKeyMonitor.install { event in
                if event.keyCode == 53 { appState.cancelCapture() }
                return event
            }
        }
    }

    /// sel：SwiftUI 左上原点矩形。直接按像素比例裁剪冻结帧（同为左上原点，无翻转）。
    private func confirmSelection(_ sel: CGRect) {
        guard let cg = CaptureEngine.shared.cropFrozen(sel) else {
            appState.flashToast("截图失败：无冻结帧")
            appState.cancelCapture()
            return
        }
        let img = NSImage(cgImage: cg, size: sel.size)
        if overlay.forOCR {
            appState.editorImage = img
            appState.phase = .ocr
            OCRService.shared.recognize(image: img) { res in
                DispatchQueue.main.async {
                    appState.lastOCRResult = res
                    appState.openOCRWindow()
                    appState.phase = .idle
                    CaptureEngine.shared.dismissOverlay()
                }
            }
        } else {
            appState.editorImage = img
            appState.phase = .annotating
            overlay.enterAnnotating(image: img, selection: sel)
        }
    }
}

// MARK: - 标注态视图（iShot 式：截图留在原位，外部暗遮罩，工具栏浮岛在选区下方）

struct InPlaceEditorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var doc = AnnotationDocument()
    @State private var selectedTool: AnnotationKind? = nil
    let image: NSImage
    let selection: CGRect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 外部暗遮罩（挖空选区）
                Color.black.opacity(0.55)
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: selection.width, height: selection.height)
                                    .position(x: selection.midX, y: selection.midY)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
                    .allowsHitTesting(false)

                // 截图贴在选区原位
                Image(nsImage: image)
                    .resizable()
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
                    .allowsHitTesting(false)

                // 标注画布（与选区同尺寸同位置，标注画在此层）
                CanvasView(doc: doc, selectedTool: $selectedTool)
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
                    .clipped()
                    .allowsHitTesting(true)

                // 选区边界线：标注态保留，明示截图区域定位
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: selection.width, height: selection.height)
                    .position(x: selection.midX, y: selection.midY)
                    .allowsHitTesting(false)
            }
            // 编辑浮岛（双岛并排，各自独立）：
            // 主岛 = 候选条（上）+ 工具栏（下）同一容器、一条发丝线（决策 #6）
            // 操作岛 = 保存/取消/复制（纯图标，单独成区）
            // 全屏 ZStack 底部锚定：候选条出现/收起时工具栏不动，向上生长
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 0) {
                        if let tool = selectedTool {
                            CandidateBar(tool: tool, doc: doc)
                            Divider().opacity(0.6).padding(.horizontal, 10)
                        }
                        EditorToolbar(selectedTool: $selectedTool,
                                      doc: doc,
                                      onOCR: handleOCR)
                    }
                    .fixedSize(horizontal: true, vertical: false)   // 岛宽=最宽行内容，无空白
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

                    EditorActionsBar(onSave: handleSave,
                                     onCancel: { appState.cancelCapture() },
                                     onCopy: handleCopy)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, islandBottomInset(geo: geo.size))
            }
        }
        .onAppear {
            doc.image = image
            doc.canvasSize = selection.size
            doc.undoStack.commit([])
            OverlayKeyMonitor.install { [weak doc] event in
                if event.keyCode == 53 { appState.cancelCapture() }
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "z" {
                    if event.modifierFlags.contains(.shift) { doc?.redo() } else { doc?.undo() }
                }
                return event
            }
        }
    }

    /// 浮岛底边距屏幕底部的 inset（底部锚定）。
    /// 优先级：选区下方（紧贴）→ 选区上方 → 屏幕中央（全屏/极大选区）。结果 clamp 在可视区内。
    private func islandBottomInset(geo: CGSize) -> CGFloat {
        let margin: CGFloat = 16
        let belowY = selection.maxY + margin          // 期望：浮岛底边的屏幕 y
        if belowY <= geo.height - 20 {
            return max(6, geo.height - belowY)
        }
        let aboveBottom = selection.minY - 16         // 上方方案：浮岛贴选区上沿
        if aboveBottom >= 90 {                        // 至少容纳工具栏高度
            return max(6, geo.height - aboveBottom)
        }
        return max(6, geo.height / 2 - 90)            // 全屏兜底：屏幕中央
    }

    private func handleCopy() {
        guard let rendered = doc.renderFlattened() else { return }
        appState.finishWithCopy(rendered)
    }

    private func handleSave() {
        guard let rendered = doc.renderFlattened() else { return }
        let (ok, path) = FileService.shared.saveToDefaultPath(rendered)
        appState.flashToast(ok ? "已保存至 \(path)" : "保存失败：无法写入 \(path)")
    }

    private func handleOCR() {
        // 渲染含标注的成品图 → 复制（受"自动复制"开关控制）→ 收起编辑器 → 识别成品 → 弹结果
        guard let rendered = doc.renderFlattened() else { return }
        if AppSettings.shared.autoCopy {
            ClipboardService.shared.copyImage(rendered)
        }
        appState.editorImage = rendered

        // 先收起覆盖层，再开始识别（结果到达后弹 OCR 面板）
        appState.phase = .idle
        OverlayState.shared.reset()
        CaptureEngine.shared.dismissOverlay()

        OCRService.shared.recognize(image: rendered) { res in
            DispatchQueue.main.async {
                appState.lastOCRResult = res
                appState.flashToast("已复制标注截图")
                appState.openOCRWindow()
            }
        }
    }
}

// MARK: - 选区视觉：青蓝描边 + 八向手柄 + 尺寸标签
/// 坐标系：selection 为 SwiftUI 左上原点，直接使用。
struct SelectionChrome: View {
    let selection: CGRect
    let containerSize: CGSize

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1.5)
                .frame(width: selection.width, height: selection.height)
                .position(x: selection.midX, y: selection.midY)

            Text(sizeLabel)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.accentColor)
                .cornerRadius(5)
                .position(x: selection.minX + sizeLabelWidth / 2,
                          y: selection.minY - 18)

            ForEach(handlePositions, id: \.self) { pos in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.accentColor, lineWidth: 1))
                    .frame(width: 9, height: 9)
                    .position(x: pos.x, y: pos.y)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private var sizeLabel: String { "\(Int(selection.width)) × \(Int(selection.height))" }
    private var sizeLabelWidth: CGFloat { CGFloat(sizeLabel.count) * 7 + 16 }

    private var handlePositions: [CGPoint] {
        let x0 = selection.minX, x1 = selection.midX, x2 = selection.maxX
        let y0 = selection.minY, y1 = selection.midY, y2 = selection.maxY
        return [
            CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y0), CGPoint(x: x2, y: y0),
            CGPoint(x: x0, y: y1), CGPoint(x: x2, y: y1),
            CGPoint(x: x0, y: y2), CGPoint(x: x1, y: y2), CGPoint(x: x2, y: y2),
        ]
    }
}

/// 底部提示胶囊
struct HintPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
    }
}
