# Snapsol

自分専用の macOS スクリーンショットアプリ。メニューバーに常駐し、撮ってすぐ共有・注釈・文字の読み取りができる。
[Screendrop](https://github.com/fayazara/screendrop)（CC0）を参考に、最小構成でゼロから作り直したもの。

## 機能

| 操作 | 既定のキー |
| --- | --- |
| 全画面を撮影（カーソルのあるディスプレイ） | ⌥1 |
| ウィンドウを撮影 | ⌥2 |
| 範囲を撮影 | ⌥3 |
| 範囲の文字をコピー（OCR、日本語・英語） | ⌥4 |

- 撮影後、右下にプレビューカードが積まれる。コピー・保存・注釈・削除・他アプリへのドラッグができる。ホバー中は自動で閉じない
- 注釈エディタ: 矩形・矢印・テキスト・モザイク、選択/移動/リサイズ、取り消し。保存すると画像に焼き込まれる
- 撮影履歴: メニューバーに直近 5 件（クリックでコピー）、一覧ウィンドウ
- 設定: ホットキーの変更、撮影後の動作（カード表示 / 自動コピー / エディタを開く）、カードを閉じるまでの秒数

保存場所:

- 撮影履歴: `~/Library/Application Support/Snapsol/`（`History/` と `history.json`）
- 「保存」の書き出し先: `~/Pictures/Snapsol/`

## ビルド

必要なもの: macOS 26 以降、Xcode 27、[XcodeGen](https://github.com/yonaskolb/XcodeGen)

```sh
xcodegen generate
xcodebuild -project Snapsol.xcodeproj -scheme Snapsol -derivedDataPath build build
open build/Build/Products/Debug/Snapsol.app
```

テスト:

```sh
xcodebuild -project Snapsol.xcodeproj -scheme Snapsol -derivedDataPath build test
```

アプリアイコンは `Resources/Snapsol.icon`（Icon Composer で開いて編集できる）。ビルド時に actool が `Assets.car` へコンパイルする。

初回起動時に「画面収録」の許可を求められる。システム設定で許可したあと、アプリを再起動する。
Team ID 付きで署名しているので、再ビルドしても許可は外れない。

## 構成

```
Snapsol/
├─ App/             AppDelegate と AppContainer（依存を組み立てる唯一の場所）
├─ Domain/          値型と純粋なロジック（注釈・ホットキー・履歴・読み順・カードの状態機械）
├─ Application/     ユースケースと状態（撮影フロー・履歴・ホットキー・エディタ）と Ports（protocol）
├─ Infrastructure/  Ports の実装（screencapture・Carbon・Vision・ファイル・描画）
└─ Presentation/    AppKit / SwiftUI の UI
```

依存の向きは次のとおり。Infrastructure は Application が定義する Ports（protocol）を実装する。

```
Presentation ─→ Application ─→ Domain
                    ↑
             Infrastructure
```

テストターゲットは App と Presentation を含めずにコンパイルするので、Domain / Application / Infrastructure が
Presentation や App の型を参照するとテストのビルドが失敗する。
ただし `import AppKit` などのフレームワーク利用はコンパイラでは検出されないので、レビューで守る。
