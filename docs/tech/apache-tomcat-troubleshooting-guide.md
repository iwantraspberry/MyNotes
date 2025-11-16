# Apache + Tomcat環境のトラブルシューティングガイド

**作成日:** 2025-01-16  
**作成者:** @iwantraspberry

---

## 📋 目次

1. [問題の概要](#問題の概要)
2. [問題の切り分け方法](#問題の切り分け方法)
3. [コンテナ環境での検証手順](#コンテナ環境での検証手順)
4. [ポートマッピング構成での検証](#ポートマッピング構成での検証)
5. [404エラーの原因と対処](#404エラーの原因と対処)
6. [基本概念の解説](#基本概念の解説)
7. [Tomcat完全ガイド](#tomcat完全ガイド)

---

## 問題の概要

JavaでREST APIを作成し、Apache + Tomcat環境で動かそうとしている。
- **構成:** Apache（Webサーバー） → Tomcat（アプリケーションサーバー）
- **問題:** Apacheからの転送がうまく機能していない

### 環境情報
- **Apache:** ホストPC 9015ポート
- **Tomcat:** ホストPC 9016ポート
- **アプリ:** Spring Boot + OpenAPI構成、ROOT.warでデプロイ
- **実行環境:** Dockerコンテナ

---

## 問題の切り分け方法

### ステップ1: 各層の独立動作確認

#### Tomcat単体での動作確認
```bash
# Tomcatに直接アクセスして動作確認
curl http://localhost:8080/your-api-path
```

**確認ポイント:**
- Tomcatが起動しているか（`catalina.out`ログ確認）
- REST APIアプリケーションがデプロイされているか
- Tomcat単体でAPIレスポンスが返るか

#### Apache単体での動作確認
```bash
# Apacheの起動確認
systemctl status httpd  # または apache2
# エラーログ確認
tail -f /var/log/httpd/error_log
```

### ステップ2: Apache-Tomcat連携の確認ポイント

#### 接続方式の確認

**mod_proxy_http の場合:**
```apache
<VirtualHost *:80>
    ProxyPass /api http://localhost:8080/api
    ProxyPassReverse /api http://localhost:8080/api
</VirtualHost>
```

**mod_proxy_ajp の場合:**
```apache
<VirtualHost *:80>
    ProxyPass /api ajp://localhost:8009/api
    ProxyPassReverse /api ajp://localhost:8009/api
</VirtualHost>
```

#### ポート・プロトコルの確認
```bash
# Tomcatのリスニングポート確認
netstat -tlnp | grep java
# または
ss -tlnp | grep java
```

**期待される結果:**
- HTTP: 8080ポート
- AJP: 8009ポート（mod_jk/mod_proxy_ajp使用時）

### ステップ3: よくある問題と確認方法

#### 問題1: モジュールが有効化されていない
```bash
# Apacheモジュール確認（CentOS/RHEL）
httpd -M | grep -E 'proxy|jk'

# Debian/Ubuntu
apache2ctl -M | grep -E 'proxy|jk'
```

**必要なモジュール（proxy使用時）:**
```apache
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
# AJP使用時
LoadModule proxy_ajp_module modules/mod_proxy_ajp.so
```

#### 問題2: ファイアウォール/SELinux
```bash
# ファイアウォール確認
firewall-cmd --list-all

# SELinux確認（有効な場合）
getsebool -a | grep httpd
# 必要に応じて
setsebool -P httpd_can_network_connect 1
```

#### 問題3: コンテキストパス不一致
```bash
# Tomcatのデプロイ確認
ls -la /var/lib/tomcat/webapps/
```

---

## コンテナ環境での検証手順

### Step 1: Tomcatコンテナ単体での動作確認

#### 方法A: コンテナ内部から確認（推奨）
```bash
# Tomcatコンテナに入る
docker exec -it <tomcat-container-name> bash

# コンテナ内でcurl実行
curl http://localhost:8080/your-api-path

# curlがない場合はインストール
apt-get update && apt-get install -y curl
```

#### 方法B: ホストマシンからコンテナのポートに直接アクセス
```bash
# Tomcatコンテナのポートマッピング確認
docker ps

# ホストからアクセス（ポートが公開されている場合）
curl http://localhost:<mapped-port>/your-api-path
```

### Step 2: Apache-Tomcat間のネットワーク確認

#### コンテナ構成の確認
```bash
# コンテナ一覧
docker ps

# ネットワーク確認
docker network ls
docker network inspect <network-name>
```

#### 同一ネットワーク内の複数コンテナの場合

```yaml
# docker-compose.yml の例
services:
  apache:
    image: httpd:2.4
    ports:
      - "9015:80"
    networks:
      - app-network
  
  tomcat:
    image: tomcat:9
    ports:
      - "9016:8080"
    networks:
      - app-network

networks:
  app-network:
```

**疎通確認:**
```bash
# Apacheコンテナから Tomcatコンテナへの疎通確認
docker exec -it <apache-container> bash

# コンテナ名またはサービス名で接続
curl http://tomcat:8080/your-api-path

# pingで名前解決確認
ping tomcat
```

---

## ポートマッピング構成での検証

### 前提条件
- Apache: ホスト9015 → コンテナ内80
- Tomcat: ホスト9016 → コンテナ内8080

### Step 1: Tomcat単体での動作確認

```bash
# ホストPCから9016ポートにアクセス
curl http://localhost:9016/your-api-path

# 詳細表示
curl -v http://localhost:9016/your-api-path

# REST APIのテスト例
curl -X GET http://localhost:9016/api/users
```

### Step 2: Apache-Tomcat連携の検証

#### ⚠️ 重要: よくある間違い

```apache
# ❌ 間違い: Apacheコンテナ内から localhost:9016 は使えない！
ProxyPass /api http://localhost:9016/api
```

**理由:** Apacheコンテナ内の`localhost`は**Apacheコンテナ自身**を指す

#### ✅ 正しい設定方法

**パターンA: コンテナ名/サービス名を使用（推奨）**
```apache
# Tomcatコンテナ名が "tomcat" の場合
ProxyPass /api http://tomcat:8080/api
ProxyPassReverse /api http://tomcat:8080/api

# コンテナ内のポート8080を指定（9016ではない！）
```

**パターンB: コンテナのIPアドレスを使用**
```bash
# TomcatコンテナのIPアドレス確認
docker inspect <tomcat-container-name> | grep IPAddress
```

```apache
# 例: IPが172.18.0.3の場合
ProxyPass /api http://172.18.0.3:8080/api
ProxyPassReverse /api http://172.18.0.3:8080/api
```

### Step 3: 段階的な疎通確認

```bash
# 1. Tomcatコンテナへの到達確認（Apacheコンテナから）
docker exec -it <apache-container-name> bash
curl http://tomcat:8080/api/test
ping tomcat

# 2. ホストPCからApache経由でアクセス
curl http://localhost:9015/api/test

# 詳細ログ付き
curl -v http://localhost:9015/api/test
```

### よくある問題と解決策

#### 問題1: 「502 Bad Gateway」エラー

**原因:** Apacheコンテナから Tomcatコンテナに到達できない

**確認:**
```bash
docker exec -it <apache-container-name> curl http://tomcat:8080
```

**解決策:**
```apache
ProxyPass /api http://tomcat:8080/api  ← コンテナ名:8080
```

#### 問題2: 「404 Not Found」エラー

**原因:** コンテキストパスの不一致

**確認:**
```bash
curl http://localhost:9016/
curl http://localhost:9016/api/
curl http://localhost:9016/your-app/api/
```

---

## 404エラーの原因と対処

**404が返ってくる = リクエストはTomcatに届いているが、パスが見つからない**

### Step 1: Tomcatのデフォルトページ確認

```bash
# ルートパスにアクセス
curl -v http://localhost:9016/
```

### Step 2: 実際にデプロイされているファイル確認

```bash
# ROOT.warが展開されているか確認
docker exec <tomcat-container-name> ls -la /usr/local/tomcat/webapps/

# ROOTディレクトリの中身を確認
docker exec <tomcat-container-name> ls -la /usr/local/tomcat/webapps/ROOT/

# WEB-INFが存在するか
docker exec <tomcat-container-name> ls -la /usr/local/tomcat/webapps/ROOT/WEB-INF/
```

### Step 3: Spring Bootアプリが起動しているか確認

```bash
# Catalina.outでSpring Bootの起動ログを探す
docker exec <tomcat-container-name> grep -i "Started" /usr/local/tomcat/logs/catalina.out

# エラーログ確認
docker logs <tomcat-container-name> | grep -i "error\|exception" | tail -20
```

### Step 4: 正しいパスを特定する

```bash
# OpenAPI 3.0のデフォルトパス
curl http://localhost:9016/v3/api-docs

# Swagger UIのパス
curl -I http://localhost:9016/swagger-ui/index.html
curl -I http://localhost:9016/swagger-ui.html

# Actuatorエンドポイント
curl http://localhost:9016/actuator
curl http://localhost:9016/actuator/health

# カスタムAPIエンドポイント
curl http://localhost:9016/api/
```

### 包括的なパステストスクリプト

```bash
#!/bin/bash
TOMCAT_PORT=9016

echo "=== ROOT.war展開確認 ==="
docker exec <tomcat-container-name> ls -la /usr/local/tomcat/webapps/ | grep ROOT

echo -e "\n=== Springアプリ起動確認 ==="
docker logs <tomcat-container-name> 2>&1 | grep "Started" | tail -3

echo -e "\n=== 各種パステスト ==="
echo "1. ルートパス:"
curl -s -o /dev/null -w "  http://localhost:$TOMCAT_PORT/ - %{http_code}\n" http://localhost:$TOMCAT_PORT/

echo "2. OpenAPI ドキュメント:"
curl -s -o /dev/null -w "  http://localhost:$TOMCAT_PORT/v3/api-docs - %{http_code}\n" http://localhost:$TOMCAT_PORT/v3/api-docs

echo "3. Swagger UI (パターン1):"
curl -s -o /dev/null -w "  http://localhost:$TOMCAT_PORT/swagger-ui/index.html - %{http_code}\n" http://localhost:$TOMCAT_PORT/swagger-ui/index.html

echo "4. Actuator:"
curl -s -o /dev/null -w "  http://localhost:$TOMCAT_PORT/actuator - %{http_code}\n" http://localhost:$TOMCAT_PORT/actuator
```

---

## 基本概念の解説

### 1. server.servlet.context-path とは？

アプリケーションのベースURLを設定するもの。

#### 設定しない場合（デフォルト）
```properties
# application.properties
server.servlet.context-path=/
```

**アクセスURL:**
```
http://localhost:9016/api/users
http://localhost:9016/v3/api-docs
```

#### 設定する場合
```properties
server.servlet.context-path=/myapp
```

**アクセスURL:**
```
http://localhost:9016/myapp/api/users
http://localhost:9016/myapp/v3/api-docs
```

#### ROOT.war との関係

| デプロイ方法 | context-path設定 | 実際のURL |
|------------|-----------------|-----------|
| ROOT.war | 未設定（/） | `http://localhost:9016/api/users` |
| ROOT.war | `/myapp` | `http://localhost:9016/myapp/api/users` |
| myapp.war | 未設定（/） | `http://localhost:9016/myapp/api/users` |

### 2. springdoc.* を設定していない場合の挙動

SpringDoc（OpenAPI）の依存関係を追加しただけで、**何も設定しなくても**以下のエンドポイントが自動で有効になる。

**自動的に有効になるエンドポイント:**
```
http://localhost:9016/v3/api-docs
http://localhost:9016/v3/api-docs.yaml
http://localhost:9016/swagger-ui/index.html
```

**デフォルト値:**
```properties
springdoc.api-docs.path=/v3/api-docs
springdoc.swagger-ui.path=/swagger-ui.html
springdoc.swagger-ui.enabled=true
```

**カスタマイズ例:**
```properties
# OpenAPI JSONのパスを変更
springdoc.api-docs.path=/api-docs

# Swagger UIのパスを変更
springdoc.swagger-ui.path=/swagger

# Swagger UIを無効化（本番環境など）
springdoc.swagger-ui.enabled=false
```

### 3. WEB-INF と META-INF

#### WEB-INF ディレクトリ

**概要:**
- Web Application Information の略
- **外部から直接アクセスできない**保護されたディレクトリ
- Webアプリケーションの設定ファイルやクラスファイルを格納

**構造:**
```
ROOT/
├── index.html              ← 直接アクセス可能
├── static/                 ← 直接アクセス可能
└── WEB-INF/                ← ブラウザから直接アクセス不可
    ├── web.xml             ← サーブレット設定
    ├── classes/            ← コンパイル済みJavaクラス
    │   ├── application.properties
    │   └── com/example/MyClass.class
    └── lib/                ← JARファイル（依存ライブラリ）
        ├── spring-core.jar
        └── jackson.jar
```

**アクセステスト:**
```bash
# ❌ 外部から直接アクセス不可
curl http://localhost:9016/WEB-INF/web.xml
# → 404または403エラー
```

#### META-INF ディレクトリ

**概要:**
- Meta Information の略
- JARファイルやWARファイルの**メタデータ**を格納

**構造:**
```
ROOT/
└── META-INF/
    ├── MANIFEST.MF          ← JARの基本情報
    ├── maven/               ← Mavenプロジェクト情報
    └── spring/              ← Spring関連の設定
```

**MANIFEST.MF の例:**
```
Manifest-Version: 1.0
Implementation-Title: my-rest-api
Implementation-Version: 1.0.0
Main-Class: com.example.Application
```

#### WEB-INF vs META-INF の違い

| 項目 | WEB-INF | META-INF |
|------|---------|----------|
| 用途 | Webアプリ専用 | 汎用（JAR/WAR共通） |
| 配置場所 | WARのルート直下 | JARまたはWARのルート直下 |
| 主な内容 | サーブレット設定、クラス、JSP | マニフェスト、メタデータ |
| 外部アクセス | 不可 | 不可 |

### 4. Httpd とバーチャルホスト

#### Httpdとは

Apache HTTP Serverの実行ファイル名。世界で最も使われているWebサーバーソフトウェア。

#### バーチャルホスト（VirtualHost）

**1台のサーバーで複数のWebサイトをホストする機能**

**名前ベースのバーチャルホスト（最も一般的）:**
```apache
# 1つ目のサイト
<VirtualHost *:80>
    ServerName www.example.com
    DocumentRoot /var/www/example
</VirtualHost>

# 2つ目のサイト（APIサーバー）
<VirtualHost *:80>
    ServerName api.example.com
    
    # Tomcatへプロキシ
    ProxyPreserveHost On
    ProxyPass / http://tomcat:8080/
    ProxyPassReverse / http://tomcat:8080/
</VirtualHost>
```

**ポート9015での構成例:**
```apache
Listen 9015

<VirtualHost *:9015>
    ServerName localhost
    
    # 静的ファイルは直接配信
    DocumentRoot /usr/local/apache2/htdocs
    
    # /api/* へのリクエストはTomcatへ転送
    ProxyPass /api http://tomcat:8080/api
    ProxyPassReverse /api http://tomcat:8080/api
    
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

### 5. mod_proxy について

#### mod_proxyとは

Apache HTTP Serverの**プロキシ/ゲートウェイモジュール**

**主な用途:**
1. リバースプロキシ - クライアントのリクエストをバックエンドサーバーに転送
2. ロードバランシング - 複数サーバーへ負荷分散
3. プロトコル変換 - HTTP → AJP、HTTP → WebSocketなど

**必要なモジュール:**
```apache
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_ajp_module modules/mod_proxy_ajp.so  # AJP使用時
```

#### ProxyPassの動作

```apache
ProxyPass /api http://tomcat:8080/api
```

**動作フロー:**
```
1. クライアント → Apache
   GET http://localhost:9015/api/users

2. Apache (mod_proxy)
   - "/api" で始まるリクエストを検出
   - URLを書き換え: /api/users → http://tomcat:8080/api/users

3. Apache → Tomcat
   GET http://tomcat:8080/api/users

4. Tomcat → Apache → クライアント
   レスポンス返却
```

#### ProxyPassReverse の役割

**バックエンドからのレスポンスヘッダーを書き換える**

```apache
ProxyPass /api http://tomcat:8080/api
ProxyPassReverse /api http://tomcat:8080/api
```

**必要な理由:**
```
Tomcatがリダイレクトを返す場合

【ProxyPassReverseなし】
Tomcat: Location: http://tomcat:8080/api/login
    ↓
クライアント: http://tomcat:8080/api/login にアクセス
    ❌ コンテナ名で直接アクセスできない！

【ProxyPassReverseあり】
Tomcat: Location: http://tomcat:8080/api/login
    ↓
Apache: Location: http://localhost:9015/api/login に書き換え
    ↓
クライアント: 正しくアクセス可能
    ✅
```

#### HTTPとAJPの違い

**HTTP プロキシ:**
```apache
ProxyPass /api http://tomcat:8080/api
```
- 一般的なHTTPプロトコル
- 汎用性が高い

**AJP プロキシ:**
```apache
ProxyPass /api ajp://tomcat:8009/api
```
- Apache JServ Protocol - Tomcat専用
- バイナリ形式で高速
- Tomcatの`server.xml`でAJPコネクタが必要

### 6. Tomcat ThreadPool と PORT転送

#### ThreadPool（スレッドプール）

**リクエストを処理するための「作業員（スレッド）のプール」**

**server.xml設定:**
```xml
<!-- Executor（スレッドプール）の定義 -->
<Executor name="tomcatThreadPool" 
          namePrefix="catalina-exec-" 
          maxThreads="200"
          minSpareThreads="10"/>

<!-- HTTPコネクタ -->
<Connector port="8080" 
           protocol="HTTP/1.1"
           executor="tomcatThreadPool"
           connectionTimeout="20000"/>
```

**パラメータ:**

| パラメータ | 説明 | デフォルト |
|-----------|------|-----------|
| maxThreads | 同時処理できる最大リクエスト数 | 200 |
| minSpareThreads | 常に待機するスレッド数 | 10 |
| connectionTimeout | 接続タイムアウト(ms) | 20000 |

#### PORT転送（ポートマッピング）

```yaml
services:
  tomcat:
    ports:
      - "9016:8080"  # ホスト:9016 → コンテナ:8080
```

**動作:**
```
ホストPC:9016 → コンテナ内:8080
                    │
                    ├─ ThreadPool (maxThreads=200)
                    │   ├─ Thread-1: 処理中
                    │   ├─ Thread-2: 待機中
                    │   └─ Thread-3: 処理中
                    │
                    └─ Servlet Container (Spring Boot App)
```

### 7. grep オプション

#### 基本的なgrep
```bash
grep "検索文字列" ファイル名
```

#### 頻出オプション

**-A (After) - マッチ行の後ろN行も表示**
```bash
grep -A 5 "error" /var/log/app.log
```

**-B (Before) - マッチ行の前N行も表示**
```bash
grep -B 3 "exception" catalina.out
```

**-C (Context) - マッチ行の前後N行を表示**
```bash
grep -C 2 "Started" catalina.out
```

**-r (recursive) - ディレクトリを再帰的に検索**
```bash
grep -r "context-path" /usr/local/tomcat/webapps/ROOT/
```

#### その他の重要オプション

| オプション | 説明 | 例 |
|----------|------|-----|
| `-i` | 大文字小文字を無視 | `grep -i "error" log.txt` |
| `-v` | マッチしない行を表示 | `grep -v "DEBUG" log.txt` |
| `-n` | 行番号を表示 | `grep -n "exception" app.log` |
| `-c` | マッチした行数をカウント | `grep -c "error" log.txt` |
| `-l` | マッチしたファイル名のみ | `grep -rl "TODO" ./src/` |
| `-E` | 拡張正規表現 | `grep -E "error\|warn" log.txt` |
| `-o` | マッチした部分のみ | `grep -o "http://[^ ]*"` |

#### 実践的な組み合わせ

```bash
# エラーを含む行とその前後5行を表示
grep -i -C 5 "error" /var/log/app.log

# 複数のキーワードを検索
grep -E "error|exception|failed" catalina.out

# ファイル名と行番号付きで再帰検索
grep -rn "ProxyPass" /etc/apache2/

# DEBUGログを除外
grep -v "DEBUG" app.log | grep -i "error"

# Docker環境での使用例
docker logs <container> 2>&1 | grep -A 10 -B 5 "exception"
docker exec <container> grep -rn "ProxyPass" /usr/local/apache2/conf/
```

---

## Tomcat完全ガイド

### Tomcatとは

- **Apache Tomcat** - オープンソースのJavaサーブレットコンテナ
- JavaのWebアプリケーション（WAR/JAR）を実行する環境
- Jakarta EE（旧Java EE）の一部を実装

### ディレクトリ構造

```
/usr/local/tomcat/
├── bin/                    # 実行ファイル
│   ├── catalina.sh
│   ├── startup.sh
│   └── shutdown.sh
├── conf/                   # 設定ファイル
│   ├── server.xml         # メイン設定
│   ├── web.xml
│   ├── context.xml
│   └── tomcat-users.xml
├── lib/                    # Tomcat本体のライブラリ
├── logs/                   # ログファイル
│   ├── catalina.out       # 最重要ログ
│   └── localhost.log
├── webapps/                # アプリデプロイ先
│   ├── ROOT/              # デフォルトアプリ
│   └── myapp/
└── work/                   # JSPコンパイル済みファイル
```

### 主要設定ファイル

#### server.xml
```xml
<Server port="8005" shutdown="SHUTDOWN">
  <Executor name="tomcatThreadPool" 
            maxThreads="200"
            minSpareThreads="10"/>
  
  <Service name="Catalina">
    <!-- HTTPコネクタ -->
    <Connector port="8080" 
               protocol="HTTP/1.1"
               executor="tomcatThreadPool"/>
    
    <!-- AJPコネクタ -->
    <Connector port="8009" 
               protocol="AJP/1.3"
               secretRequired="false"/>
    
    <Engine name="Catalina" defaultHost="localhost">
      <Host name="localhost" 
            appBase="webapps"
            unpackWARs="true"
            autoDeploy="true"/>
    </Engine>
  </Service>
</Server>
```

#### web.xml
```xml
<web-app>
  <!-- セッションタイムアウト（分） -->
  <session-config>
    <session-timeout>30</session-timeout>
  </session-config>
  
  <!-- サーブレットマッピング -->
  <servlet-mapping>
    <servlet-name>dispatcherServlet</servlet-name>
    <url-pattern>/</url-pattern>
  </servlet-mapping>
</web-app>
```

### 起動・停止コマンド

```bash
# 起動
/usr/local/tomcat/bin/startup.sh

# 停止
/usr/local/tomcat/bin/shutdown.sh

# デバッグモード起動
/usr/local/tomcat/bin/catalina.sh jpda start

# Docker環境
docker start <tomcat-container>
docker stop <tomcat-container>
docker logs -f <tomcat-container>
```

### アプリケーションのデプロイ

#### 方法1: WARファイルを配置
```bash
# WARファイルをwebappsにコピー
cp myapp.war /usr/local/tomcat/webapps/

# Tomcatが自動で展開
# → /usr/local/tomcat/webapps/myapp/ が作成

# アクセスURL
# http://localhost:8080/myapp/
```

#### 方法2: ROOT.warとして配置
```bash
# 既存のROOTを削除
rm -rf /usr/local/tomcat/webapps/ROOT/

# ROOT.warとして配置
cp myapp.war /usr/local/tomcat/webapps/ROOT.war

# アクセスURL（コンテキストパスなし）
# http://localhost:8080/
```

### トラブルシューティング

#### Tomcatが起動しない
```bash
# ログ確認
tail -f /usr/local/tomcat/logs/catalina.out

# よくあるエラー
# - ポート競合: "Address already in use"
# - Java未インストール: "JAVA_HOME is not defined"

# ポート使用状況確認
netstat -tlnp | grep 8080
```

#### アプリケーションが404
```bash
# デプロイ確認
ls -la /usr/local/tomcat/webapps/

# ログで展開エラー確認
grep -i "deploy" /usr/local/tomcat/logs/catalina.out
```

#### アプリケーションが起動しない
```bash
# 例外ログ確認
grep -A 20 -i "exception" /usr/local/tomcat/logs/catalina.out
```

### セキュリティのベストプラクティス

```bash
# 不要なアプリを削除（本番環境）
rm -rf /usr/local/tomcat/webapps/docs
rm -rf /usr/local/tomcat/webapps/examples
rm -rf /usr/local/tomcat/webapps/host-manager
```

```xml
<!-- エラーページのカスタマイズ -->
<error-page>
  <error-code>404</error-code>
  <location>/error/404.html</location>
</error-page>
```

---

## チェックリスト

### コンテナ起動確認
- [ ] `docker ps -a` でTomcatコンテナが`Up`状態
- [ ] `docker ps -a` でApacheコンテナが`Up`状態
- [ ] ポートマッピングが正しい（9015→80, 9016→8080）

### Tomcat単体確認
- [ ] `curl http://localhost:9016/` で応答がある
- [ ] `docker logs <tomcat>` で "Started" ログがある
- [ ] `docker exec <tomcat> ls /usr/local/tomcat/webapps/ROOT/` でファイルが展開されている

### Apache-Tomcat連携確認
- [ ] Apache設定で `http://tomcat:8080` を使用（localhost:9016 ではない）
- [ ] `ProxyPass` と `ProxyPassReverse` が両方設定されている
- [ ] `proxy_module` と `proxy_http_module` が有効
- [ ] Apacheコンテナから `curl http://tomcat:8080` で疎通できる

### Spring Boot + OpenAPI確認
- [ ] `curl http://localhost:9016/v3/api-docs` で JSON が返る
- [ ] `curl http://localhost:9016/swagger-ui/index.html` でSwagger UIにアクセスできる
- [ ] `server.servlet.context-path` が正しく設定されている（またはデフォルト）

---

## 参考コマンド集

### デバッグ用スクリプト
```bash
#!/bin/bash

echo "=== コンテナ起動確認 ==="
docker ps

echo -e "\n=== Tomcat直接アクセス ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9016/

echo -e "\n=== Apache経由アクセス ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9015/api/

echo -e "\n=== Apache→Tomcat疎通 ==="
docker exec apache curl -s -o /dev/null -w "HTTP %{http_code}\n" http://tomcat:8080/

echo -e "\n=== Tomcatログ（最新20行） ==="
docker logs tomcat --tail 20

echo -e "\n=== Apacheログ（最新20行） ==="
docker logs apache --tail 20
```

### よく使うDockerコマンド
```bash
# コンテナ一覧
docker ps -a

# ログ確認
docker logs -f <container-name>

# コンテナに入る
docker exec -it <container-name> bash

# ポートマッピング確認
docker port <container-name>

# ネットワーク確認
docker network inspect <network-name>

# ファイルコピー
docker cp myapp.war <container>:/usr/local/tomcat/webapps/

# コンテナ再起動
docker restart <container-name>
```

---

## まとめ

### 重要ポイント

1. **問題切り分けは段階的に**
   - Tomcat単体 → Apache単体 → 連携

2. **コンテナ環境での注意点**
   - Apache設定では `http://tomcat:8080` を使う
   - ホストの9016ポートはコンテナ外からのアクセス用

3. **ROOT.war構成**
   - コンテキストパスは `/`
   - OpenAPIは `/v3/api-docs` でアクセス

4. **ログは最強のデバッグツール**
   - `catalina.out` を常に確認
   - `grep -A -B` で前後のコンテキストも見る

5. **基本を押さえる**
   - WEB-INF, META-INF の役割
   - ThreadPool, ProxyPass の仕組み
   - バーチャルホストの概念

---

**作成者:** @iwantraspberry  
**最終更新:** 2025-01-16 15:38 UTC