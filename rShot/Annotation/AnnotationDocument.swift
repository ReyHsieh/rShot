//
//  AnnotationDocument.swift
//  rShot
//
//  编辑器文档：截图 + 标注数组 + 撤销栈 + 渲染扁平化输出
//

import SwiftUI
import AppKit

final class AnnotationDocument: ObservableObject {
    @Published var image: NSImage?
    @Published var items: [Annotation] = []
    @Published var undoStack = UndoStack()
    /// 画布逻辑尺寸（= 选区点尺寸）。标注坐标存于此空间；渲染输出时按此还原。
    var canvasSize: CGSize?

    // 每工具单独记忆上次设置（设计系统文档 §5.3.4）
    @Published var perToolColor: [AnnotationKind: String] = [:]
    @Published var perToolLineWidth: [AnnotationKind: CGFloat] = [:]
    @Published var perToolFilled: [AnnotationKind: Bool] = [:]
    @Published var perToolFontSize: [AnnotationKind: CGFloat] = [:]
    @Published var perToolTextStyle: [AnnotationKind: TextStyle] = [:]

    /// 数字标记当前序号
    var nextNumber: Int {
        (items.filter { $0.kind == .number }.map { Int($0.text) ?? 0 }.max() ?? 0) + 1
    }

    func color(for tool: AnnotationKind) -> String {
        perToolColor[tool] ?? "#FF3B30"
    }
    func lineWidth(for tool: AnnotationKind) -> CGFloat {
        perToolLineWidth[tool] ?? 3
    }
    func fontSize(for tool: AnnotationKind) -> CGFloat {
        perToolFontSize[tool] ?? 16
    }
    func filled(for tool: AnnotationKind) -> Bool {
        perToolFilled[tool] ?? false
    }

    func set(_ value: String, for tool: AnnotationKind) { perToolColor[tool] = value }
    func set(_ value: CGFloat, for tool: AnnotationKind) {
        perToolLineWidth[tool] = value
    }
    func setFilled(_ value: Bool, for tool: AnnotationKind) { perToolFilled[tool] = value }
    func setFontSize(_ value: CGFloat, for tool: AnnotationKind) { perToolFontSize[tool] = value }
    func textStyle(for tool: AnnotationKind) -> TextStyle { perToolTextStyle[tool] ?? .boxed }
    func setTextStyle(_ value: TextStyle, for tool: AnnotationKind) { perToolTextStyle[tool] = value }

    // MARK: - 增删改（结构性变更后提交撤销快照）

    func add(_ item: Annotation) {
        items.append(item)
        commit()
    }

    func remove(_ item: Annotation) {
        items.removeAll { $0.id == item.id }
        commit()
    }

    /// 文本编辑中实时更新内容（不产生撤销快照；提交时统一 commitSnapshot）
    func updateText(id: UUID, _ text: String) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].text = text
        }
    }

    /// 提交一次撤销快照（文本输入结束等非结构性变更后调用）
    func commitSnapshot() {
        commit()
    }

    // MARK: - 标注移动（未选中工具时拖动已有标注）

    /// 拖动中直接覆写 frame/points（不产生撤销快照；结束时 commitSnapshot）
    func moveAnnotation(id: UUID, frame: CGRect, points: [CGPoint]) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].frame = frame
        items[i].points = points
    }

    func undo() {
        if let snap = undoStack.undo() { items = snap }
    }

    func redo() {
        if let snap = undoStack.redo() { items = snap }
    }

    private func commit() {
        undoStack.commit(items)
    }

    // MARK: - 渲染扁平化（用于复制/保存）
    // 用 ImageRenderer 渲染与屏幕完全相同的 SwiftUI 视图（截图 + AnnotationView），
    // 避免 CGContext 手绘的坐标系翻转/缩放不一致——所见即所得。

    @MainActor
    func renderFlattened() -> NSImage? {
        guard let img = image, let canvas = canvasSize else { return nil }
        let sourceCG = img.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let content = ZStack {
            Image(nsImage: img)
                .resizable()
                .frame(width: canvas.width, height: canvas.height)
            ForEach(items) { item in
                AnnotationView(item: item, canvasSize: canvas, sourceImage: sourceCG)
            }
        }
        .frame(width: canvas.width, height: canvas.height)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2   // Retina 输出
        return renderer.nsImage
    }
}
