import SwiftUI

struct EditorView: View {
    @Bindable var session: EditorSession
    let baseImage: CGImage
    let mosaicSource: CGImage?
    let renderer: any AnnotationRendering
    let onCopy: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            AnnotationCanvas(
                session: session,
                baseImage: baseImage,
                mosaicSource: mosaicSource,
                renderer: renderer,
                annotations: session.annotations,
                selection: session.selection,
                tool: session.tool,
                textEditing: session.textEditing
            )
            .background(Color(nsColor: .underPageBackgroundColor))
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("ツール", selection: $session.tool) {
                ForEach(EditorTool.allCases, id: \.self) { tool in
                    Image(systemName: tool.symbol)
                        .help(tool.help)
                        .tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            HStack(spacing: 6) {
                ForEach(AnnotationColor.palette, id: \.self) { color in
                    Circle()
                        .fill(color.swiftUIColor)
                        .overlay(Circle().strokeBorder(.secondary.opacity(0.5)))
                        .frame(width: 18, height: 18)
                        .padding(2)
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: session.color == color ? 2 : 0))
                        .onTapGesture { session.color = color }
                }
            }

            Divider().frame(height: 20)

            Button("取り消す", systemImage: "arrow.uturn.backward") { session.undo() }
                .disabled(!session.canUndo)
            Button("やり直す", systemImage: "arrow.uturn.forward") { session.redo() }
                .disabled(!session.canRedo)
            Button("削除", systemImage: "trash") { session.deleteSelection() }
                .disabled(session.selection == nil)

            Spacer()

            Button("コピー", action: onCopy)
            Button("保存", action: onSave)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s")
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private extension EditorTool {
    var symbol: String {
        switch self {
        case .select: "cursorarrow"
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        case .mosaic: "checkerboard.rectangle"
        }
    }

    var help: String {
        switch self {
        case .select: "選択 (V)"
        case .rectangle: "矩形 (R)"
        case .arrow: "矢印 (A)"
        case .text: "テキスト (T)"
        case .mosaic: "モザイク (M)"
        }
    }
}

private extension AnnotationColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }
}
