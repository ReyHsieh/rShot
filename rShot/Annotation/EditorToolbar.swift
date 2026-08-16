//
//  EditorToolbar.swift  +  CandidateBar
//  rShot
//
//  底部工具栏（常驻画布下方）+ 候选条（选工具后紧贴上方展开，输入法候选词式）
//  对应 OD screen-editor.html，决策 #6
//

import SwiftUI

struct EditorToolbar: View {
    @Binding var selectedTool: AnnotationKind?
    @ObservedObject var doc: AnnotationDocument
    var onOCR: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            toolButton(.rect, "rectangle", "矩形框选")
            toolButton(.text, "R", "文本")   // 文本工具：字母 R
            toolButton(.number, "number.circle", "数字标记")

            Divider().frame(height: 22).padding(.horizontal, 4)

            toolButton(.arrow, "arrow.up.right", "箭头")
            toolButton(.highlight, "highlighter", "高亮笔")
            toolButton(.mosaic, "squareshape.split.3x3", "马赛克")
            toolButton(.pen, "scribble", "画笔")

            Divider().frame(height: 22).padding(.horizontal, 4)

            iconButton("arrow.uturn.backward", help: "撤销",
                       disabled: !doc.undoStack.canUndo) { doc.undo() }
            iconButton("arrow.uturn.forward", help: "重做",
                       disabled: !doc.undoStack.canRedo) { doc.redo() }

            Divider().frame(height: 22).padding(.horizontal, 4)

            iconButton("text.viewfinder", help: "文字识别（OCR）") { onOCR() }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        // 背景由外层 EditorIsland 统一提供（决策 #6：候选条+工具栏同一容器，一条发丝线分隔）
    }

    /// 图标按钮：统一 34×34 命中区
    @ViewBuilder
    private func iconButton(_ systemName: String, help: String,
                            disabled: Bool = false,
                            color: Color? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundColor(color)
        .help(help)
        .disabled(disabled)
    }

    @ViewBuilder
    private func toolButton(_ kind: AnnotationKind, _ icon: String, _ help: String) -> some View {
        Button {
            selectedTool = (selectedTool == kind) ? nil : kind
        } label: {
            Group {
                if icon.count == 1 {
                    // 单字符 = 字母图标（如文本工具的 "R"）
                    Text(icon)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                } else {
                    Image(systemName: icon)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 16))
                }
            }
            .frame(width: 34, height: 34)
            .background(selectedTool == kind ? Color.accentColor : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .foregroundColor(selectedTool == kind ? .white : .primary)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// 候选条：随工具变化，颜色 / 线宽 / 填充等，输入法候选词式（横向单行）
struct CandidateBar: View {
    let tool: AnnotationKind
    @ObservedObject var doc: AnnotationDocument

    var body: some View {
        HStack(spacing: 16) {
            switch tool {
            case .rect:
                colorPicker(.rect)
                segLine(.rect)
            case .text:
                segTextStyle()
                segTextSize()
                colorPicker(.text)
            case .number:
                colorPicker(.number)
                HStack(spacing: 6) {
                    Text("序号").font(.caption).foregroundStyle(.secondary)
                    Text("\(doc.nextNumber)").monospacedDigit()
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            case .arrow:
                colorPicker(.arrow)
                segLine(.arrow)
            case .highlight:
                colorPicker(.highlight)
            case .mosaic:
                Text("拖拽框选马赛克区域").font(.caption).foregroundStyle(.secondary)
            case .pen:
                colorPicker(.pen)
                segLine(.pen)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        // 背景由外层 EditorIsland 统一提供（决策 #6）
    }

    // MARK: - 候选项组件

    @ViewBuilder
    private func colorPicker(_ tool: AnnotationKind) -> some View {
        HStack(spacing: 7) {
            Text("颜色").font(.caption).foregroundStyle(.secondary)
            ForEach(Palette.colors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .overlay(Circle().strokeBorder(.white.opacity(0.3)))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().strokeBorder(Color.accentColor, lineWidth: 2)
                            .opacity(doc.color(for: tool) == hex ? 1 : 0)
                    )
                    .onTapGesture { doc.set(hex, for: tool) }
            }
        }
    }

    @ViewBuilder
    private func segLine(_ tool: AnnotationKind) -> some View {
        HStack(spacing: 6) {
            Text("线宽").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { lineSegValue(doc.lineWidth(for: tool)) },
                set: { doc.set(segToWidth($0), for: tool) }
            )) {
                Text("细").tag("thin")
                Text("中").tag("mid")
                Text("粗").tag("thick")
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    @ViewBuilder
    private func segTextStyle() -> some View {
        HStack(spacing: 6) {
            Text("样式").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { doc.textStyle(for: .text) },
                set: { doc.setTextStyle($0, for: .text) }
            )) {
                Text("透明").tag(TextStyle.transparent)
                Text("底框").tag(TextStyle.boxed)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
        }
    }

    @ViewBuilder
    private func segTextSize() -> some View {
        HStack(spacing: 6) {
            Text("字号").font(.caption).foregroundStyle(.secondary)
            Picker("", selection: Binding(
                get: { textSizeSeg(doc.fontSize(for: .text)) },
                set: { doc.setFontSize(textSegToSize($0), for: .text) }
            )) {
                Text("小").tag("s")
                Text("中").tag("m")
                Text("大").tag("l")
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }
    }

    private func lineSegValue(_ w: CGFloat) -> String {
        w <= 1.5 ? "thin" : (w >= 4 ? "thick" : "mid")
    }
    private func segToWidth(_ s: String) -> CGFloat {
        s == "thin" ? 1.5 : (s == "thick" ? 5 : 3)
    }
    private func textSizeSeg(_ s: CGFloat) -> String {
        s <= 13 ? "s" : (s >= 22 ? "l" : "m")
    }
    private func textSegToSize(_ s: String) -> CGFloat {
        s == "s" ? 13 : (s == "l" ? 24 : 16)
    }
}

/// 完成操作浮岛（独立于主工具栏，单独成区）：保存 / 取消 / 复制·完成（纯图标）
struct EditorActionsBar: View {
    @ObservedObject private var settings = AppSettings.shared
    var onSave: () -> Void
    var onCancel: () -> Void
    var onCopy: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            actionButton("square.and.arrow.down",
                         help: "保存到默认路径") { onSave() }
            actionButton("xmark",
                         help: "取消截图",
                         color: .secondary) { onCancel() }
            actionButton(settings.autoCopy ? "doc.on.doc" : "checkmark",
                         help: settings.autoCopy ? "复制 / 完成" : "完成",
                         prominent: true) { onCopy() }
        }
        .padding(.horizontal, 6).padding(.vertical, 8)
    }

    @ViewBuilder
    private func actionButton(_ systemName: String, help: String,
                              color: Color? = nil, prominent: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16, weight: prominent ? .semibold : .regular))
                .frame(width: 34, height: 34)
                .background(prominent ? Color.accentColor : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(prominent ? .white : (color ?? .primary))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
