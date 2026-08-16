//
//  IMETextEditor.swift
//  rShot
//
//  多行文本编辑（NSTextView 包装）。
//  替代 SwiftUI TextEditor：后者的 text binding 在拼音组合（marked text）期间不更新，
//  导致框宽不随拼音扩展、长拼音被折行（表现为"纵向拓展"）。
//  NSTextView 的 textDidChange 实时回调完整串（含拼音）→ 框优雅横向展开。
//

import AppKit
import SwiftUI

struct IMETextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: NSColor
    var onCommit: () -> Void      // ⌘Enter
    var onCancel: () -> Void      // ESC
    var onEndEditing: () -> Void  // 失焦

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        let tv = NSTextView()
        tv.font = .systemFont(ofSize: fontSize, weight: .medium)
        tv.textColor = textColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        // 尺寸由 SwiftUI frame 控制：内容不撑开视图、不滚动
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 5
        tv.textContainerInset = NSSize(width: 2, height: 2)
        tv.delegate = context.coordinator
        tv.string = text
        // 创建即聚焦（点开放置文本 → 直接输入）
        DispatchQueue.main.async { [weak tv] in
            tv?.window?.makeFirstResponder(tv)
        }
        return tv
    }

    func updateNSView(_ tv: NSTextView, context: Context) {
        // 拼音组合中（marked）不回写，避免打断输入法
        if tv.string != text, !tv.hasMarkedText() {
            tv.string = text
        }
        tv.textColor = textColor
        if let f = tv.font, abs(f.pointSize - fontSize) > 0.1 {
            tv.font = .systemFont(ofSize: fontSize, weight: .medium)
        }
        // 垂直居中：底框高度略大于内容时，内容下沉居中；
        // 多行时内容≈占满，inset 收回 2，自然顶部贴合（换行视觉不失衡）
        if let lm = tv.layoutManager, let container = tv.textContainer {
            lm.ensureLayout(for: container)
            let glyphRange = lm.glyphRange(for: container)
            let contentH = lm.boundingRect(forGlyphRange: glyphRange,
                                           in: container).height
            let viewH = tv.bounds.height
            let inset: CGFloat = viewH > contentH + 8
                ? max(2, (viewH - contentH) / 2)
                : 2
            tv.textContainerInset = NSSize(width: 2, height: inset)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: IMETextEditor
        init(_ parent: IMETextEditor) { self.parent = parent }

        /// 内容变化（含拼音组合串）→ 实时驱动框宽
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            NSLog("[rShot-IME] didChange: \(String(tv.string.prefix(24)))")
            parent.text = tv.string
        }

        /// 兜底信号：拼音组合时光标/选择区必然变化（部分系统 marked 期间不触发 textDidChange）
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            if parent.text != tv.string {
                NSLog("[rShot-IME] selection-change sync")
                parent.text = tv.string
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onEndEditing()
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false   // 回车（含 ⌘Enter）统一放行 → 换行；提交靠失焦
        }
    }
}
