# My Learning Notes

MkDocs Material を使用した学習ノートとナレッジベースプロジェクトです。

## 📚 概要

このプロジェクトは、読書や様々な学びを体系的に蓄積・整理するためのドキュメントサイトです。Markdownで記述したコンテンツをMkDocs Materialを使って美しいWebアプリケーションとして表示できます。

## 🏗️ プロジェクト構造

```
docs/
├── index.md              # ホームページ
├── books/                # 読書ノート
│   ├── index.md
│   └── [書籍別フォルダ]
├── learning/             # 学習ノート
│   ├── index.md
│   └── [分野別フォルダ]
└── tech/                 # 技術メモ
    ├── index.md
    └── [技術別フォルダ]
```

## 🚀 セットアップ

### 前提条件

- Python 3.8以上
- pip

### インストール

1. 依存関係をインストール:
```bash
pip install -r requirements.txt
```

2. 開発サーバーを起動:
```bash
mkdocs serve
```

3. ブラウザで `http://127.0.0.1:8000` にアクセス

### ビルド

静的サイトをビルドする場合:
```bash
mkdocs build
```

## 🐳 Docker で使う

DockerがあればPython環境なしでも動かせます。

- 開発（ホットリロード）:
```bash
# dev サービスで起動（http://localhost:8000）
docker compose up --build docs-dev
```

- 本番（静的サイトをnginxで配信）:
```bash
# prod サービスで起動（http://localhost:8080）
docker compose up --build docs-prod
```

- 単体Dockerで開発サーバー:
```bash
# イメージをdevターゲットでビルド
DOCKER_BUILDKIT=1 docker build --target dev -t mynotes-dev .
# 起動
docker run --rm -it -p 8000:8000 -v "$PWD":/docs mynotes-dev
```

- 単体Dockerで本番静的配信:
```bash
# prodターゲットでイメージをビルド
DOCKER_BUILDKIT=1 docker build --target prod -t mynotes-prod .
# 起動（http://localhost:8080）
docker run --rm -it -p 8080:80 mynotes-prod
```

ヒント:
- Apple Silicon(M1/M2/M3)でも対応可能なベースイメージを使用しています。
- docker compose v2（`docker compose`）を想定しています。

## 📝 使い方

### 新しいノートを追加

1. `docs/` ディレクトリ内の適切なカテゴリフォルダにMarkdownファイルを作成
2. `mkdocs.yml` の `nav` セクションにエントリを追加（自動検出も可能）
3. `mkdocs serve` で変更を確認

### カテゴリ

- **読書ノート** (`books/`): 書籍の要約、感想、学んだポイント
- **学習ノート** (`learning/`): 勉強した内容、講座のまとめ
- **技術メモ** (`tech/`): プログラミング、ツール、技術的な発見

### タグ機能

Markdownファイルの先頭に以下のようにタグを追加できます:

```yaml
---
tags:
  - 読書
  - ビジネス
---
```

## 🎨 カスタマイズ

- テーマカラーやフォントは `mkdocs.yml` で変更可能
- CSSカスタマイズは `docs/stylesheets/extra.css`
- JavaScriptカスタマイズは `docs/javascripts/` フォルダ

## 📦 主要な機能

- 📱 レスポンシブデザイン
- 🌙 ダークモード対応
- 🔍 全文検索
- 📑 ナビゲーション
- 🏷️ タグシステム
- 📊 数式表示（MathJax）
- 📈 図表（Mermaid）
- 💻 コードハイライト

## 🔧 開発

VS Codeタスクが設定されており、以下のコマンドが使用できます:

- **Serve**: 開発サーバーの起動
- **Build**: 本番用ビルド
- **Deploy**: サイトのデプロイ（設定が必要）

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。