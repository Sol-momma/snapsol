import SwiftUI

struct PreviewStackView: View {
    let controller: PreviewPanelController

    var body: some View {
        VStack(spacing: PreviewPanelController.spacing) {
            // 最新のカードを画面の角に一番近い下端に置く
            ForEach(controller.entries.reversed()) { entry in
                let url = controller.history.fileURL(for: entry)
                PreviewCardView(
                    url: url,
                    image: controller.thumbnails.thumbnail(at: url, version: entry.updatedAt, maxPixelSize: 480)
                ) { action in
                    controller.handle(action, for: entry)
                }
            }
        }
        .padding(PreviewPanelController.margin)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onHover { controller.setHovering($0) }
    }
}

private struct PreviewCardView: View {
    let url: URL
    let image: CGImage?
    let onAction: (PreviewCardAction) -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            thumbnail
            // 他アプリへ渡し終えたらカードの役目は終わりなので閉じる
            FileDragSource(url: url, image: image) { onAction(.close) }
            if isHovering {
                // 暗幕はクリックを素通しにして、下のドラッグ元に届くようにする
                Color.black.opacity(0.5).allowsHitTesting(false)
                controls
            }
        }
        .frame(width: PreviewPanelController.cardSize.width, height: PreviewPanelController.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.25)))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: PreviewPanelController.cardSize.width, height: PreviewPanelController.cardSize.height)
                .clipped()
        } else {
            Color.gray.opacity(0.4)
        }
    }

    /// よく使う「コピー」「保存」を中央に大きく置き、それ以外は四隅の丸ボタンにする
    private var controls: some View {
        ZStack {
            VStack(spacing: 8) {
                textButton("コピー", action: .copy)
                textButton("保存", action: .save)
            }
            VStack {
                HStack {
                    iconButton("xmark", help: "閉じる", action: .close)
                    Spacer()
                    iconButton("trash", help: "削除", action: .delete)
                }
                Spacer()
                HStack {
                    iconButton("pencil", help: "注釈", action: .annotate)
                    Spacer()
                }
            }
            .padding(8)
        }
    }

    private static let buttonBackground = Color(white: 0.86)
    private static let buttonForeground = Color(white: 0.12)

    private func iconButton(_ systemName: String, help: String, action: PreviewCardAction) -> some View {
        Button { onAction(action) } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Self.buttonForeground)
                .frame(width: 26, height: 26)
                .background(Self.buttonBackground, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func textButton(_ title: String, action: PreviewCardAction) -> some View {
        Button { onAction(action) } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Self.buttonForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Self.buttonBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
