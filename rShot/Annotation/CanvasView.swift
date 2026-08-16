//
//  CanvasView.swift
//  rShot
//
//  画布：截图背景 + 标注渲染 + 鼠标绘制交互 + 文本就地编辑
//

import SwiftUI
import AppKit

struct CanvasView: View {
    @ObservedObject var doc: AnnotationDocument
    @Binding var selectedTool: AnnotationKind?

    @State private var draftStart: CGPoint? = nil
    @State private var draftEnd: CGPoint? = nil
    @State private var draftPoints: [CGPoint] = []
    @State private var editingTextID: UUID? = nil
    @State private var textDraft: String = ""

    /// 底图 CGImage（供马赛克像素化取样）
    private var sourceCGImage: CGImage? {
        doc.image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    var body: some View {
        GeometryReader { geo in
            let imgSize = doc.image?.size ?? geo.size
            let fitSize = aspectFit(imgSize, in: geo.size)
            ZStack {
                if let img = doc.image {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fitSize.width, height: fitSize.height)
                        .allowsHitTesting(false)
                }

                // 标注层：无论是否选中工具，标注始终可命中：
                // - 在已有标注上拖动 = 移动该标注（子视图手势优先）
                // - 在空白处拖动 = 容器手势创建新标注
                // - 文本双击 = 就地编辑
                ForEach(doc.items) { item in
                    if item.kind == .text && editingTextID == item.id {
                        textEditorField(for: item)
                    } else {
                        movableAnnotation(item, canvas: fitSize)
                    }
                }

                // 草稿预览（拖动过程可见，含马赛克；画笔用完整轨迹）
                if let tool = selectedTool, let s = draftStart, let e = draftEnd {
                    DraftPreview(tool: tool, start: s, end: e,
                                 color: doc.color(for: tool),
                                 lineWidth: doc.lineWidth(for: tool),
                                 points: draftPoints)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: fitSize.width, height: fitSize.height)
            .contentShape(Rectangle())
            .gesture(drawGesture(in: fitSize))
            .clipped()
        }
    }

    // MARK: - 标注移动（未选工具时拖动）

    @State private var movingID: UUID? = nil
    @State private var moveInitialFrame: CGRect = .zero
    @State private var moveInitialPoints: [CGPoint] = []

    private func movableAnnotation(_ item: Annotation, canvas: CGSize) -> some View {
        AnnotationView(item: item, canvasSize: canvas, sourceImage: sourceCGImage)
            .modifier(AnnotationHitShape(item: item))
            .contextMenu {
                Button("删除标注", action: { doc.remove(item) })
            }
            .onTapGesture(count: 2) {
                if item.kind == .text { beginEditing(item) }
            }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if movingID != item.id {
                            movingID = item.id
                            moveInitialFrame = item.frame
                            moveInitialPoints = item.points
                        }
                        let dx = v.translation.width, dy = v.translation.height
                        doc.moveAnnotation(
                            id: item.id,
                            frame: moveInitialFrame.offsetBy(dx: dx, dy: dy),
                            points: moveInitialPoints.map {
                                CGPoint(x: $0.x + dx, y: $0.y + dy)
                            })
                    }
                    .onEnded { _ in
                        if movingID != nil {
                            doc.commitSnapshot()
                            movingID = nil
                        }
                    }
            )
    }

    // MARK: - 文本就地编辑

    /// 多行编辑（IMETextEditor）：Enter 换行、⌘Enter 提交、失焦自动提交、ESC 取消。
    /// 尺寸随输入自适应（含拼音组合串，横向优雅展开），顶部锚定向下生长。
    private func textEditorField(for item: Annotation) -> some View {
        let box = AnnotationTextLayout.boxSize(for: textDraft,
                                               fontSize: item.fontSize,
                                               isEditing: true)
        return IMETextEditor(
            text: bindingForDraft(of: item),
            fontSize: item.fontSize,
            textColor: item.textStyle == .boxed
                ? .white
                : NSColor(Color(hex: item.colorHex)),
            onCommit: { commitTextEditing(item) },
            onCancel: { cancelTextEditing(item) },
            onEndEditing: {
                // 失焦即提交：点工具栏/画布去做别的事时，文字不丢失（空则删）
                if editingTextID == item.id { commitTextEditing(item) }
            }
        )
        .background(
            // 底框模式：彩底；透明模式：无底
            Group {
                if item.textStyle == .boxed {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: item.colorHex))
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.9), lineWidth: 1.5))
        .frame(width: box.width, height: box.height, alignment: .topLeading)
        .position(x: AnnotationTextLayout.anchorX(for: textDraft, item: item),
                  y: item.frame.minY + box.height / 2)
    }

    /// 草稿与数据实时同步：输入即写入 item.text（不产生撤销快照，提交时统一快照）
    private func bindingForDraft(of item: Annotation) -> Binding<String> {
        Binding(
            get: { editingTextID == item.id ? textDraft : item.text },
            set: { newValue in
                if editingTextID == item.id {
                    textDraft = newValue
                    doc.updateText(id: item.id, newValue)
                }
            }
        )
    }

    private func beginEditing(_ item: Annotation) {
        textDraft = item.text
        editingTextID = item.id
        // 聚焦由 IMETextEditor 创建时自动 makeFirstResponder
    }

    private func commitTextEditing(_ item: Annotation) {
        guard editingTextID == item.id else { return }
        let text = textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            doc.remove(item)
        } else {
            doc.updateText(id: item.id, text)
            doc.commitSnapshot()
        }
        editingTextID = nil
    }

    private func cancelTextEditing(_ item: Annotation) {
        guard editingTextID == item.id else { return }
        if item.text.isEmpty { doc.remove(item) }
        editingTextID = nil
    }

    // MARK: - 绘制手势

    private func drawGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard let tool = selectedTool else { return }
                let p = clamped(v.location, in: size)
                if tool == .pen {
                    if draftPoints.isEmpty { draftPoints = [p] }
                    else { draftPoints.append(p) }
                    draftStart = draftPoints.first
                    draftEnd = p
                } else {
                    if draftStart == nil { draftStart = p }
                    draftEnd = p
                }
            }
            .onEnded { v in
                guard let tool = selectedTool, let s = draftStart else {
                    draftStart = nil; draftEnd = nil; draftPoints = []
                    return
                }
                let e = draftEnd ?? s
                // 单击（拖动距离过小）：text/number 是点击放置，保留；
                // 区域类工具丢弃过小的误触，避免生成看不见的标注污染撤销栈
                let w = abs(e.x - s.x), h = abs(e.y - s.y)
                switch tool {
                case .text, .number:
                    commit(tool: tool, start: s, end: s)
                case .pen:
                    if draftPoints.count >= 2 || w > 4 || h > 4 {
                        commit(tool: tool, start: s, end: e)
                    }
                default:
                    if w > 6 || h > 6 {
                        commit(tool: tool, start: s, end: e)
                    }
                }
                draftStart = nil; draftEnd = nil; draftPoints = []
            }
    }

    private func commit(tool: AnnotationKind, start: CGPoint, end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch tool {
        case .rect:
            doc.add(Annotation(kind: .rect, frame: rect,
                               colorHex: doc.color(for: .rect),
                               lineWidth: doc.lineWidth(for: .rect),
                               filled: doc.filled(for: .rect)))
        case .number:
            // 数字标记以按下位置为圆心，固定尺寸
            let size: CGFloat = 28
            doc.add(Annotation(kind: .number,
                               frame: CGRect(x: start.x - size/2, y: start.y - size/2,
                                             width: size, height: size),
                               colorHex: doc.color(for: .number),
                               text: "\(doc.nextNumber)"))
        case .text:
            // 文本：点击放置 → 弹出就地输入框（样式取工具记忆：底框/透明）
            let fontSize = doc.fontSize(for: .text)
            let item = Annotation(kind: .text,
                                  frame: CGRect(origin: start,
                                                size: CGSize(width: 160, height: fontSize + 12)),
                                  colorHex: doc.color(for: .text),
                                  text: "",
                                  textStyle: doc.textStyle(for: .text),
                                  fontSize: fontSize)
            doc.add(item)
            beginEditing(item)
        case .arrow:
            doc.add(Annotation(kind: .arrow, frame: rect,
                               colorHex: doc.color(for: .arrow),
                               lineWidth: doc.lineWidth(for: .arrow),
                               points: [start, end]))
        case .highlight:
            doc.add(Annotation(kind: .highlight, frame: rect,
                               colorHex: doc.color(for: .highlight)))
        case .mosaic:
            doc.add(Annotation(kind: .mosaic, frame: rect))
        case .pen:
            doc.add(Annotation(kind: .pen, frame: rect,
                               colorHex: doc.color(for: .pen),
                               lineWidth: doc.lineWidth(for: .pen),
                               points: draftPoints))
        }
    }

    // MARK: - 辅助
    private func clamped(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(0, p.x), size.width), y: min(max(0, p.y), size.height))
    }
    private func aspectFit(_ s: CGSize, in c: CGSize) -> CGSize {
        guard s.width > 0 && s.height > 0 else { return c }
        let scale = min(c.width / s.width, c.height / s.height)
        return CGSize(width: s.width * scale, height: s.height * scale)
    }
}

/// 文本标注的统一尺寸/锚点：编辑框与最终渲染共用同一测量 → 提交不跳位。
/// 初始一行高、两字宽；随文本增多自适应宽高（宽度封顶）。
enum AnnotationTextLayout {
    static let maxWidth: CGFloat = 340   // 渲染宽度上限（超出自动换行增高）
    static let hPad: CGFloat = 24        // 左右余量合计（含 TextEditor 内建边距）
    static let vPad: CGFloat = 14        // 上下余量合计（含内建边距，禁滚动后防裁切）

    /// 测量文本所需盒子尺寸：空文本按占位"两个字"计（初始两字宽 × 一行高）。
    /// isEditing 时宽度上限放宽（拼音组合中的长字母串不换行 → 框不纵向抖动）；
    /// 选定汉字后按确认文本宽度正常收缩，提交/渲染仍按 maxWidth 封顶。
    static func boxSize(for text: String, fontSize: CGFloat, isEditing: Bool = false) -> CGSize {
        let cap = isEditing ? CGFloat(800) : maxWidth
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let content = text.isEmpty ? "文字" : text   // 空时占位：两字宽
        let attr = NSAttributedString(string: content, attributes: [.font: font])
        var size = attr.boundingRect(
            with: NSSize(width: cap - hPad, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size
        size.width = min(max(size.width + hPad, fontSize * 2 + hPad), cap)
        size.height = max(size.height + vPad, fontSize * 1.5 + vPad)
        return size
    }

    /// position 中心 X：左缘对齐 frame.minX
    static func anchorX(for text: String, item: Annotation) -> CGFloat {
        item.frame.minX + boxSize(for: text, fontSize: item.fontSize).width / 2
    }
}

/// 命中区域策略（缩小误触）：
/// - 矩形：仅描边环带命中（内部空白穿透，可在矩形内画新标注）
/// - 箭头/画笔：沿线条 ±13pt 命中（包围盒空白穿透）
/// - 高亮/马赛克/数字：整块 frame（它们本身是实心区域）
/// - 文本：不加 contentShape，按文字实际内容命中
private struct AnnotationHitShape: ViewModifier {
    let item: Annotation
    func body(content: Content) -> some View {
        switch item.kind {
        case .text:
            content
        default:
            content.contentShape(AnnotationHitArea(item: item))
        }
    }
}

/// 按标注类型生成精确命中 Path（画布绝对坐标）
struct AnnotationHitArea: Shape {
    let item: Annotation

    func path(in rect: CGRect) -> Path {
        switch item.kind {
        case .rect:
            // 描边环带：矩形边线两侧各 ~11pt
            Path(item.frame)
                .strokedPath(StrokeStyle(lineWidth: item.lineWidth + 20, lineJoin: .miter))
        case .arrow:
            ArrowShape(points: item.points, lineWidth: item.lineWidth)
                .path(in: rect)
                .strokedPath(StrokeStyle(lineWidth: item.lineWidth + 24,
                                          lineCap: .round, lineJoin: .round))
        case .pen:
            PenPath(points: item.points)
                .path(in: rect)
                .strokedPath(StrokeStyle(lineWidth: item.lineWidth + 24,
                                          lineCap: .round, lineJoin: .round))
        default:
            // 高亮/马赛克/数字：整块
            Path(item.frame)
        }
    }
}

/// 单个标注的渲染（SwiftUI 层）
struct AnnotationView: View {
    let item: Annotation
    let canvasSize: CGSize
    /// 底图（马赛克像素化取样用）
    var sourceImage: CGImage? = nil

    var body: some View {
        let color = Color(hex: item.colorHex)
        switch item.kind {
        case .rect:
            if item.filled {
                color.opacity(0.2)
                    .frame(width: item.frame.width, height: item.frame.height)
                    .overlay(Rectangle().stroke(color, lineWidth: item.lineWidth))
                    .position(x: item.frame.midX, y: item.frame.midY)
            } else {
                Rectangle().stroke(color, lineWidth: item.lineWidth)
                    .frame(width: item.frame.width, height: item.frame.height)
                    .position(x: item.frame.midX, y: item.frame.midY)
            }
        case .number:
            Text(item.text)
                .font(.system(size: min(item.frame.width * 0.55, 16), weight: .bold))
                .foregroundColor(.white)
                .frame(width: item.frame.width, height: item.frame.height)
                .background(Circle().fill(color))
                .position(x: item.frame.midX, y: item.frame.midY)
                .shadow(color: .black.opacity(0.2), radius: 1)
        case .text:
            // 空文本不渲染（失焦提交逻辑会移除空项，此处防御色块残留）
            if !item.text.isEmpty {
                // 与编辑框共用测量：宽=文本自适应（封顶），多行高度自适应
                let box = AnnotationTextLayout.boxSize(for: item.text,
                                                       fontSize: item.fontSize)
                Group {
                    if item.textStyle == .boxed {
                        // 底框模式：彩底白字
                        Text(item.text)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(color))
                    } else {
                        // 透明模式：无底无边，颜色为文字色
                        Text(item.text)
                            .foregroundColor(color)
                            .padding(.horizontal, 2).padding(.vertical, 2)
                    }
                }
                .font(.system(size: item.fontSize, weight: .medium))
                .frame(width: box.width, height: box.height, alignment: .center)
                .position(x: AnnotationTextLayout.anchorX(for: item.text, item: item),
                          y: item.frame.minY + box.height / 2)
            }
        case .arrow:
            // points 为画布绝对坐标；Shape 包在 frame+position 局部坐标系里，需平移到局部
            ArrowShape(points: item.points,
                       origin: item.frame.origin,
                       lineWidth: item.lineWidth)
                .stroke(color, style: StrokeStyle(lineWidth: item.lineWidth,
                                                   lineCap: .round, lineJoin: .round))
                .frame(width: max(item.frame.width, 1), height: max(item.frame.height, 1))
                .position(x: item.frame.midX, y: item.frame.midY)
        case .highlight:
            color.opacity(0.3)
                .frame(width: item.frame.width, height: item.frame.height)
                .position(x: item.frame.midX, y: item.frame.midY)
        case .mosaic:
            // 真·马赛克：对底图对应区域缩小再无插值放大（像素块）
            if let cg = sourceImage,
               let mosaic = MosaicRenderer.pixelated(from: cg, frame: item.frame,
                                                     canvas: canvasSize, blockSize: 16) {
                Image(nsImage: mosaic)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: item.frame.width, height: item.frame.height)
                    .position(x: item.frame.midX, y: item.frame.midY)
            } else {
                // 无底图兜底：灰色半透明
                LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: item.frame.width, height: item.frame.height)
                    .position(x: item.frame.midX, y: item.frame.midY)
            }
        case .pen:
            PenPath(points: item.points, origin: item.frame.origin)
                .stroke(color, style: StrokeStyle(lineWidth: item.lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: max(item.frame.width, 1), height: max(item.frame.height, 1))
                .position(x: item.frame.midX, y: item.frame.midY)
        }
    }
}

/// 拖动草稿预览（含马赛克，松手前即可看到将生效的区域；画笔用完整轨迹）
struct DraftPreview: View {
    let tool: AnnotationKind
    let start: CGPoint
    let end: CGPoint
    let color: String
    let lineWidth: CGFloat
    var points: [CGPoint] = []

    var body: some View {
        let c = Color(hex: color)
        let w = abs(end.x - start.x), h = abs(end.y - start.y)
        let cx = (start.x + end.x)/2, cy = (start.y + end.y)/2
        switch tool {
        case .rect:
            Rectangle().stroke(c, lineWidth: lineWidth)
                .frame(width: w, height: h).position(x: cx, y: cy)
        case .arrow:
            ArrowShape(points: [start, end], lineWidth: lineWidth)
                .stroke(c, style: StrokeStyle(lineWidth: lineWidth,
                                               lineCap: .round, lineJoin: .round))
        case .highlight:
            c.opacity(0.3).frame(width: w, height: h).position(x: cx, y: cy)
        case .mosaic:
            // 预览用半透明网格示意，松手后为真实像素化
            LinearGradient(colors: [.gray.opacity(0.55), .gray.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: w, height: h).position(x: cx, y: cy)
                .overlay(Rectangle().stroke(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        case .pen:
            PenPath(points: points.isEmpty ? [start, end] : points)
                .stroke(c, lineWidth: lineWidth)
        default:
            EmptyView()
        }
    }
}

// MARK: - Shapes

/// 箭头：线段 + 实心三角头（自适应线宽）。
/// points 为画布绝对坐标；包在 frame+position 局部坐标系时传 origin 做平移。
struct ArrowShape: Shape {
    let points: [CGPoint]
    var origin: CGPoint = .zero
    var lineWidth: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count >= 2 else { return p }
        let s = CGPoint(x: points[0].x - origin.x, y: points[0].y - origin.y)
        let e = CGPoint(x: points[1].x - origin.x, y: points[1].y - origin.y)
        p.move(to: s); p.addLine(to: e)
        let angle = atan2(e.y - s.y, e.x - s.x)
        let len = max(10, lineWidth * 3.5)
        p.move(to: e)
        p.addLine(to: CGPoint(x: e.x - len * cos(angle - .pi / 7),
                              y: e.y - len * sin(angle - .pi / 7)))
        p.addLine(to: CGPoint(x: e.x - len * cos(angle + .pi / 7),
                              y: e.y - len * sin(angle + .pi / 7)))
        p.closeSubpath()
        return p
    }
}

struct PenPath: Shape {
    let points: [CGPoint]
    var origin: CGPoint = .zero

    init(points: [CGPoint], origin: CGPoint = .zero) {
        self.points = points
        self.origin = origin
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.x - origin.x, y: first.y - origin.y))
        for pt in points.dropFirst() {
            p.addLine(to: CGPoint(x: pt.x - origin.x, y: pt.y - origin.y))
        }
        return p
    }
}
