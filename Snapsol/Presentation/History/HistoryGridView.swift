import SwiftUI

/// 撮影履歴の一覧。ダブルクリックで注釈、右クリックで各操作。
struct HistoryGridView: View {
    struct Actions {
        var copy: (HistoryEntry) -> Void
        var save: (HistoryEntry) -> Void
        var annotate: (HistoryEntry) -> Void
        var reveal: (HistoryEntry) -> Void
        var delete: (HistoryEntry) -> Void
    }

    let history: HistoryService
    let thumbnails: any ThumbnailProviding
    let actions: Actions

    var body: some View {
        if history.entries.isEmpty {
            ContentUnavailableView(
                "撮影履歴はまだありません",
                systemImage: "photo.on.rectangle",
                description: Text("メニューバーのアイコンかホットキーから撮影できます")
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
                    ForEach(history.entries) { entry in
                        HistoryCell(entry: entry, url: history.fileURL(for: entry), thumbnails: thumbnails)
                            .onTapGesture(count: 2) { actions.annotate(entry) }
                            .contextMenu { menu(for: entry) }
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func menu(for entry: HistoryEntry) -> some View {
        Button("コピー") { actions.copy(entry) }
        Button("~/Pictures/Snapsol に保存") { actions.save(entry) }
        Button("注釈を付ける") { actions.annotate(entry) }
        Button("Finder で表示") { actions.reveal(entry) }
        Divider()
        Button("ゴミ箱に入れる", role: .destructive) { actions.delete(entry) }
    }
}

private struct HistoryCell: View {
    let entry: HistoryEntry
    let url: URL
    let thumbnails: any ThumbnailProviding
    @State private var image: CGImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            }
            .frame(height: 120)
            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        // updatedAt が変わる（注釈で上書きされる）と読み直す。デコードはメインスレッドの外で行う
        .task(id: entry.updatedAt) {
            let thumbnails = thumbnails, url = url, version = entry.updatedAt
            image = await Task.detached {
                thumbnails.thumbnail(at: url, version: version, maxPixelSize: 360)
            }.value
        }
    }
}
