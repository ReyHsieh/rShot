//
//  OCRResultView.swift
//  rShot
//
//  OCR 结果面板（对应 OD screen-ocr.html）：识别中 / 完成 / 失败 三态
//

import SwiftUI

struct OCRResultView: View {
    @EnvironmentObject var appState: AppState
    @State private var editableText: String = ""
    @State private var loading: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 头部
            HStack {
                Label("识别文本", systemImage: "text.viewfinder")
                    .font(.headline)
                Spacer()
                Text("中文 · 离线")
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            .padding(14)
            Divider()

            // 内容
            if loading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("识别中…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = appState.lastOCRResult {
                TextEditor(text: $editableText)
                    .font(.system(size: 13))
                    .padding(14)
            } else {
                ContentUnavailableView("暂无识别结果", systemImage: "text.viewfinder")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 底部操作
            Divider()
            HStack {
                Spacer()
                Button("编辑") { editableText = appState.lastOCRResult?.fullText ?? "" }
                Button {
                    let text = editableText.isEmpty ? (appState.lastOCRResult?.fullText ?? "") : editableText
                    ClipboardService.shared.copyText(text)
                    appState.flashToast("已复制识别文本")
                } label: {
                    Label("复制全部", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
        }
        .frame(minWidth: 440, minHeight: 360)
        .onChange(of: appState.lastOCRResult) { _ in
            loading = false
            editableText = appState.lastOCRResult?.fullText ?? ""
        }
        .onAppear {
            if appState.lastOCRResult == nil { loading = true }
            else { editableText = appState.lastOCRResult?.fullText ?? "" }
        }
    }
}
