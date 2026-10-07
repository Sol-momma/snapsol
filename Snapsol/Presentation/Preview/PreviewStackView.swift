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
                Color.black.opacity(0.35).allowsHitTesting(false)
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

    private var controls: some View {
        VStack {
            HStack {
                iconButton("xmark", help: "閉じる", action: .close)
                Spacer()
                iconButton("trash", help: "削除", action: .delete)
            }
            Spacer()
            HStack(spacing: 6) {
                textButton("コピー", action: .copy)
                textButton("保存", action: .save)
                textButton("注釈", action: .annotate)
            }
        }
        .padding(8)
    }

    private func iconButton(_ systemName: String, help: String, action: PreviewCardAction) -> some View {
        Button { onAction(action) } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22, height: 22)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func textButton(_ title: String, action: PreviewCardAction) -> some View {
        Button { onAction(action) } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
