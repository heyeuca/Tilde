# App Store Connect Listing (Tilde v1.4.0)

The limits below are App Store Connect's. Run `python3 scripts/check_listing.py` before pasting any field into App Store Connect: it checks every field's length and its characters.

| Field | Limit |
| --- | ---: |
| Name | 30 |
| Subtitle | 30 |
| Promotional Text | 170 |
| Description | 4000 |
| Keywords | 100 (commas included) |
| What's New | 4000 |

### Characters

App Store Connect refuses some characters in listing fields, and Apple doesn't publish which. In 1.3.0 it refused the Control Pictures `␀` and `␛` in What's New. So listing text uses only:

- printable ASCII and line breaks;
- letters, marks, and digits of any script, except presentation forms;
- the symbols App Store Connect has already accepted, listed in `ACCEPTED_SYMBOLS` in `scripts/check_listing.py`: `·` `—` `•` `⇧` `⌘` `▸` `、` `。` `「` `」` `・`.

Describe any other character in words, as What's New does for control codes ("show as dimmed symbols"). Add a symbol to `ACCEPTED_SYMBOLS` only after App Store Connect has accepted it. CI runs the check on every pull request.

---

## Shared (all locales)

| Field | Value |
| --- | --- |
| Bundle ID | `co.euca.Tilde` |
| SKU | `tilde-macos` |
| Version | `1.4.0` |
| Primary Language | English (U.S.) |
| Primary Category | Productivity |
| Secondary Category | Developer Tools |
| Price | Free (Tier 0) |
| Availability | All countries/regions |
| Copyright | `© 2026 euca` |
| Age Rating | 4+ ("None" for every questionnaire item) |
| Support URL | `https://github.com/heyeuca/Tilde` |
| Marketing URL (optional) | `https://github.com/heyeuca/Tilde` |
| Privacy Policy URL (required) | `https://github.com/heyeuca/Tilde/blob/main/PRIVACY.md` ([PRIVACY.md](../PRIVACY.md) at the repository root) |
| Content Rights | No third-party content (No) |
| Export Compliance | No non-exempt encryption → "None of the algorithms mentioned above" (exempt when the app only makes standard HTTPS calls). With `ITSAppUsesNonExemptEncryption = NO` in Info.plist, App Store Connect doesn't ask on every build |
| Government End Users | Not applicable |

### App Privacy (Privacy Nutrition Label)

- Choose **Data Not Collected**. No server communication, accounts, analytics, or ad SDKs.
- Tracking: No.

### App Review Information

- Sign-in required: **No**
- Contact: name / phone / email (enter by hand)
- Notes (in English):

```
Tilde is a lightweight, document-based plain-text and Markdown editor for macOS.
It runs fully offline: there is no account, no server communication, no analytics,
and no in-app purchases.

How to test:
1. Launch the app. An empty document window opens (or press ⌘N).
2. Type some Markdown, e.g. "# Hello" and "**bold**". Headings and emphasis are
   styled in place while the syntax stays visible.
3. Save with ⌘S as "test.md". Save is only enabled for user-chosen locations
   (App Sandbox, com.apple.security.files.user-selected.read-write).
4. Press ⌘⇧R (or the title-bar toggle) to open Reader mode: a rendered,
   read-only view. Press Esc to return to the editor.
5. Open any .txt / .json / .yaml file via ⌘O to see plain-text and light
   syntax highlighting.

Note on local images/links in Reader: because of the App Sandbox, a Markdown
image that references a neighboring local file may show its alt text instead
of the image unless macOS has granted access to that file. This is expected.
```

- Attachment: not required (attaching one sample `.md` file makes review easier; `README.md` works well)

### Screenshots (macOS: at least 1, up to 10)

Accepted sizes: 1280×800, 1440×900, 2560×1600, 2880×1800. Suggested set (2880×1800, at least one each in light and dark):

1. Editing a Markdown document (headings, bold, and code styled with their syntax still visible)
2. Reader mode (a rendered table and code block)
3. Quiet key highlighting in a `.json` or `.yaml` file
4. Editing in dark mode
5. The Find & Replace bar
6. The Settings window (Appearance / Line numbers / Word wrap)

---

## English (U.S.) — Primary

**Name**
```
Tilde
```

**Subtitle**
```
Tiny, quiet text & Markdown
```

**Promotional Text**
```
Open the file. Read it. Change a line. Close it. Tilde is a native macOS editor for .txt and .md that stays out of your way — no projects, no plugins, no accounts.
```

**Keywords**
```
text editor,markdown,plain text,txt,md,notes,readme,reader,lightweight,minimal,json,yaml,writer
```

**Description**
```
Tilde is a tiny, beautiful text editor for macOS — built for people who just want to open a plain-text or Markdown file, read it, maybe change a line, and close it.

No projects. No workspaces. No plugins. No sidebars. No accounts. The editor disappears so the content is all that's left.

WHY TILDE
Full IDEs and note apps are heavy tools for a light job. When all you need is to glance at a README, tweak a config file, or read a Markdown document, Tilde opens instantly and behaves exactly like a built-in macOS app.

MARKDOWN, DONE LIGHTLY
• Headings, bold, italic, strikethrough, inline code, code blocks, blockquotes, links, lists, and rules are styled in place
• The Markdown syntax stays visible — Tilde makes it easier to read, not hidden
• Reader mode (⌘⇧R): a fully rendered, read-only view with tables, highlighted code blocks and task-list checkboxes; toggle it from the title bar like Safari's Reader
• YAML frontmatter stays quiet in the editor and becomes a tidy header in Reader: the title on top, the other fields as rows
• ⌘-click a link in the editor to follow it: jump to a heading, open a local file, or open a web page
• Format menu: ⌘B for bold, ⌘I for italic, ⌘K to turn the selection into a link to a copied URL. Type * or ` over a selection to wrap it

PLAIN TEXT AND CONFIG FILES
• Opens .txt, .md, .markdown and most UTF-based text files: .json, .yaml, .toml, .xml, .csv, .log, .env and more — even files with no extension, like Dockerfile or SSH keys
• Quiet syntax highlighting for .json, .yaml and .toml — keys tinted, everything else left alone
• Files in unsupported encodings open read-only so the original bytes are never damaged
• Tab follows each file's indentation: spaces or tabs, at the file's own width
• Invisible characters such as zero-width spaces, bidirectional controls and no-break spaces get a faint mark

A REAL MAC APP
• Document-based: one file, one window, with window tabs
• Open With, file associations, Recent Documents, Autosave, Versions, Full Screen
• Undo/redo, drag and drop, spell check, Find & Replace
• Word wrap (on by default) and optional line numbers
• Light, Dark and System appearance using macOS semantic colors
• Interface in English, Korean, Japanese and Simplified Chinese, following your macOS language
• Fast launch and near-zero idle resource usage

PRIVATE BY DESIGN
Everything happens on your Mac. No server uploads, no sign-in, no cloud storage, no AI features, no analytics.

WHAT TILDE IS NOT
Tilde is intentionally not an IDE, a project workspace, a note database, or a Markdown authoring suite. If you need Git, terminals, plugins or multi-file navigation, Tilde is the wrong tool — on purpose.

Tilde is open source under the MIT License.

Just open the file.
```

**What's New in This Version**
```
• New Format menu for Markdown: Bold (⌘B) and Italic (⌘I) wrap the selection in Markdown markers or take them off, and Add Link (⌘K) turns the selection into a link, using a URL you have copied. Typing *, _, `, ~, [, ( or " over a selection wraps it instead of replacing it
• Copying a task list from Reader as plain text now gives empty and checked box characters instead of an invisible placeholder
• Links whose address contains parentheses, like Wikipedia's, and README badges are now styled as one link in the editor, and ⌘-click opens the full address
• Save As and Duplicate keep a file's extension, such as .json or .sh, and its permissions, so a copy of a private key stays private
```

---

## Korean

**Name**
```
Tilde
```

**Subtitle**
```
작고 조용한 텍스트·Markdown 편집기
```

**Promotional Text**
```
파일을 열고, 읽고, 한 줄 고치고, 닫는다. Tilde는 .txt와 .md를 위한 네이티브 macOS 편집기입니다. 프로젝트도, 플러그인도, 계정도 없습니다.
```

**Keywords**
```
텍스트 편집기,마크다운,메모장,txt,md,readme,리더,가벼운,미니멀,json,yaml,글쓰기,에디터
```

**Description**
```
Tilde는 작고 아름다운 macOS 텍스트 편집기입니다. 텍스트나 Markdown 파일을 열어 읽고, 필요하면 한 줄 고치고, 닫는 사람을 위해 만들었습니다.

프로젝트도, 워크스페이스도, 플러그인도, 사이드바도, 계정도 없습니다. 편집기는 사라지고 내용만 남습니다.

왜 Tilde인가
README를 잠깐 확인하거나 설정 파일 한 줄을 고치거나 Markdown 문서를 읽는 데 IDE나 노트 앱은 너무 무겁습니다. Tilde는 즉시 열리고, macOS 기본 앱처럼 동작합니다.

가볍게 다듬은 Markdown
• 제목, 굵게, 기울임, 취소선, 인라인 코드, 코드 블록, 인용, 링크, 목록, 구분선을 제자리에서 스타일링
• Markdown 문법은 그대로 보입니다. 숨기는 것이 아니라 읽기 쉽게 만듭니다
• Reader 모드(⌘⇧R): 표, 코드 하이라이팅, 작업 목록 체크박스를 포함한 완전 렌더링 읽기 전용 화면. Safari의 읽기 도구처럼 타이틀 바에서 전환
• YAML 프론트매터는 편집기에서 조용히 표시되고, Reader 모드에서는 맨 위의 제목과 행으로 정리된 항목으로 보여 줍니다
• 편집기에서 링크를 ⌘-클릭하면 따라갑니다: 제목으로 이동하거나, 로컬 파일이나 웹 페이지를 엽니다
• 포맷 메뉴: ⌘B로 볼드체, ⌘I로 이탤릭체, ⌘K로 선택한 텍스트를 복사해 둔 URL의 링크로 만듭니다. 선택한 텍스트 위에 * 나 `를 입력하면 감쌉니다

일반 텍스트와 설정 파일
• .txt, .md, .markdown은 물론 .json, .yaml, .toml, .xml, .csv, .log, .env 등 대부분의 UTF 기반 텍스트 파일 지원. Dockerfile이나 SSH 키처럼 확장자가 없는 파일도 열림
• .json, .yaml, .toml은 키만 살짝 색을 입히는 조용한 하이라이팅
• 지원하지 않는 인코딩의 파일은 읽기 전용으로 열어 원본을 절대 손상시키지 않습니다
• Tab은 파일의 들여쓰기를 따릅니다: 파일이 쓰는 너비의 공백 또는 탭
• 폭 없는 공백, 양방향 제어 문자, 줄바꿈 없는 공백 같은 보이지 않는 문자를 옅게 표시

진짜 Mac 앱
• 문서 기반: 파일 하나에 창 하나, 윈도우 탭 지원
• 다음으로 열기, 파일 연결, 최근 항목, 자동 저장, 버전, 전체 화면
• 실행 취소/다시 실행, 드래그 앤 드롭, 맞춤법 검사, 찾기 및 바꾸기
• 자동 줄바꿈(기본 켜짐), 줄 번호 표시 옵션
• macOS 시맨틱 색상을 사용하는 라이트 / 다크 / 시스템 모드
• 한국어, 영어, 일본어, 중국어(간체) 인터페이스, macOS 언어 설정을 따름
• 빠른 실행, 대기 시 리소스 사용 거의 없음

설계부터 프라이버시
모든 처리는 Mac 안에서 끝납니다. 서버 업로드, 로그인, 클라우드 저장, AI 기능, 분석 수집이 없습니다.

Tilde가 아닌 것
Tilde는 의도적으로 IDE도, 프로젝트 워크스페이스도, 노트 데이터베이스도, Markdown 저작 도구도 아닙니다. Git, 터미널, 플러그인, 여러 파일 탐색이 필요하다면 Tilde는 일부러 맞지 않는 도구입니다.

Tilde는 MIT 라이선스의 오픈 소스입니다.

그냥 파일을 여세요.
```

**What's New in This Version**
```
• Markdown용 포맷 메뉴가 생겼습니다. 볼드체(⌘B)와 이탤릭체(⌘I)는 선택한 텍스트를 Markdown 기호로 감싸거나 기호를 걷어 내고, 링크 추가(⌘K)는 복사해 둔 URL로 선택한 텍스트를 링크로 만듭니다. 텍스트를 선택한 채 *, _, `, ~, [, (, "를 입력하면 지우지 않고 감쌉니다
• Reader에서 작업 목록을 일반 텍스트로 복사하면 보이지 않는 대체 문자 대신 빈 상자와 체크된 상자 문자가 들어갑니다
• 위키백과처럼 주소에 괄호가 들어간 링크와 README 배지를 편집기에서 하나의 링크로 표시하고, ⌘-클릭하면 전체 주소를 엽니다
• 다른 이름으로 저장과 복제가 .json, .sh 같은 확장자와 파일 권한을 유지합니다. 비밀 키의 사본도 나만 읽을 수 있게 남습니다
```

---

## Japanese

**Name**
```
Tilde
```

**Subtitle**
```
小さく静かなテキスト・Markdown
```

**Promotional Text**
```
ファイルを開いて、読んで、一行直して、閉じる。Tildeは.txtと.mdのためのネイティブmacOSエディタです。プロジェクトもプラグインもアカウントもありません。
```

**Keywords**
```
テキストエディタ,マークダウン,メモ,txt,md,readme,リーダー,軽量,ミニマル,json,yaml,執筆,エディタ
```

**Description**
```
Tildeは小さく美しいmacOS用テキストエディタです。テキストやMarkdownファイルを開いて読み、必要なら一行だけ直して閉じる。そんな使い方のために作りました。

プロジェクトも、ワークスペースも、プラグインも、サイドバーも、アカウントもありません。エディタは消え、内容だけが残ります。

なぜTildeか
READMEをちょっと確認する、設定ファイルを一行直す、Markdownを読む。そのためにIDEやノートアプリは重すぎます。Tildeは一瞬で開き、macOS標準アプリのように振る舞います。

軽く整えたMarkdown
• 見出し、太字、斜体、取り消し線、インラインコード、コードブロック、引用、リンク、リスト、区切り線をその場でスタイリング
• Markdown記法はそのまま見えます。隠すのではなく読みやすくします
• リーダーモード(⌘⇧R): 表やコードハイライト、タスクリストのチェックボックスを含む完全レンダリングの読み取り専用表示。Safariのリーダーのようにタイトルバーから切り替え
• YAMLフロントマターはエディタでは控えめに表示し、リーダーモードではタイトルを先頭に、ほかの項目を行に並べたヘッダーとして表示
• エディタでリンクを⌘-クリックしてたどれます: 見出しへ移動、ローカルファイルやWebページを開く
• フォーマットメニュー: ⌘Bでボールド、⌘Iでイタリック、⌘Kで選択範囲をコピーしたURLへのリンクに。選択範囲の上で * や ` を入力すると囲みます

プレーンテキストと設定ファイル
• .txt、.md、.markdownに加え、.json、.yaml、.toml、.xml、.csv、.log、.envなどUTF系テキストファイルの多くを開けます。Dockerfileや SSH鍵など、拡張子のないファイルも開けます
• .json、.yaml、.tomlはキーだけを淡く色付けする静かなハイライト
• 未対応エンコーディングのファイルは読み取り専用で開き、元のバイト列を決して壊しません
• Tabはファイルのインデントに従います: ファイルと同じ幅のスペース、またはタブ
• ゼロ幅スペース、双方向制御文字、ノーブレークスペースなどの見えない文字を淡く表示

本物のMacアプリ
• ドキュメントベース: 1ファイル1ウインドウ、ウインドウタブ対応
• 「このアプリケーションで開く」、ファイル関連付け、最近使った項目、自動保存、バージョン、フルスクリーン
• 取り消し/やり直し、ドラッグ&ドロップ、スペルチェック、検索と置換
• 折り返し(デフォルトオン)、行番号表示オプション
• macOSのセマンティックカラーによるライト / ダーク / システム外観
• 日本語・英語・韓国語・簡体字中国語のインターフェース。macOSの言語設定に従います
• 高速起動、アイドル時のリソース消費はほぼゼロ

設計段階からのプライバシー
すべての処理はMacの中で完結します。サーバー送信、サインイン、クラウド保存、AI機能、分析収集はありません。

Tildeでないもの
TildeはあえてIDEでも、プロジェクトワークスペースでも、ノートデータベースでも、Markdown執筆スイートでもありません。Git、ターミナル、プラグイン、複数ファイルの移動が必要なら、Tildeは意図的に合わないツールです。

TildeはMITライセンスのオープンソースです。

ただ、ファイルを開くだけ。
```

**What's New in This Version**
```
• Markdown用のフォーマットメニューを追加しました。ボールド(⌘B)とイタリック(⌘I)は選択範囲をMarkdownの記号で囲む、または記号を外します。リンクを追加(⌘K)は、コピーしたURLで選択範囲をリンクにします。テキストを選択したまま *、_、`、~、[、(、" を入力すると、置き換えずに囲みます
• リーダーモードでタスクリストをプレーンテキストとしてコピーすると、見えない代替文字ではなく、空のチェックボックスとチェック済みのチェックボックスの文字になります
• Wikipediaのように括弧を含むアドレスのリンクやREADMEのバッジを、エディタで1つのリンクとして表示し、⌘-クリックでアドレス全体を開きます
• 「別名で保存」と「複製」で、.jsonや.shなどの拡張子とファイルのアクセス権を保つようになりました。秘密鍵のコピーも自分だけが読める状態のままです
```

---

## Chinese (Simplified)

**Name**
```
Tilde
```

**Subtitle**
```
小巧安静的文本与 Markdown 编辑器
```

**Promotional Text**
```
打开文件,阅读,改一行,关闭。Tilde 是专为 .txt 和 .md 打造的原生 macOS 编辑器,没有项目、没有插件、没有账户。
```

**Keywords**
```
文本编辑器,markdown,纯文本,txt,md,笔记,readme,阅读,轻量,极简,json,yaml,写作
```

**Description**
```
Tilde 是一款小巧而美观的 macOS 文本编辑器,为这样的人而生:打开一个文本或 Markdown 文件,读一读,也许改一行,然后关掉。

没有项目,没有工作区,没有插件,没有侧边栏,没有账户。编辑器隐去,只剩内容。

为什么选择 Tilde
只是想看一眼 README、改一行配置文件或读一篇 Markdown 文档,IDE 和笔记应用都太重了。Tilde 瞬间打开,表现得就像 macOS 自带应用。

轻描淡写的 Markdown
• 标题、粗体、斜体、删除线、行内代码、代码块、引用、链接、列表和分隔线均就地渲染样式
• Markdown 语法保持可见,Tilde 让它更易读,而不是把它藏起来
• 阅读模式(⌘⇧R):完整渲染的只读视图,支持表格、代码高亮和任务列表复选框;像 Safari 阅读器一样从标题栏切换
• YAML front matter 在编辑器中安静显示,在阅读模式中呈现为整洁的标题区:标题在上,其余字段逐行排列
• 在编辑器中按住 ⌘ 点按链接即可跟随:跳到标题,或打开本地文件和网页
• 格式菜单:⌘B 粗体,⌘I 斜体,⌘K 将所选文本变成指向已拷贝网址的链接。选中文本后输入 * 或 ` 即可包裹

纯文本与配置文件
• 支持 .txt、.md、.markdown,以及 .json、.yaml、.toml、.xml、.csv、.log、.env 等大多数 UTF 编码文本文件,包括 Dockerfile、SSH 密钥等没有扩展名的文件
• .json、.yaml、.toml 采用安静的语法高亮,仅为键着色,其余保持原样
• 不支持编码的文件以只读方式打开,绝不损坏原始字节
• Tab 跟随文件的缩进:按文件自身宽度插入空格,或插入制表符
• 零宽空格、双向控制字符、不换行空格等不可见字符以淡色标出

真正的 Mac 应用
• 基于文稿:一个文件一个窗口,支持窗口标签页
• 打开方式、文件关联、最近使用、自动存储、版本、全屏
• 撤销/重做、拖放、拼写检查、查找与替换
• 自动换行(默认开启),可选行号
• 使用 macOS 语义颜色的浅色 / 深色 / 跟随系统外观
• 界面支持简体中文、英语、韩语、日语,跟随 macOS 语言设置
• 启动极快,空闲时几乎不占资源

隐私优先的设计
一切都在你的 Mac 上完成。没有服务器上传、没有登录、没有云存储、没有 AI 功能、没有数据分析。

Tilde 不是什么
Tilde 有意不做 IDE、项目工作区、笔记数据库或 Markdown 创作套件。如果你需要 Git、终端、插件或多文件导航,Tilde 刻意不适合你。

Tilde 基于 MIT 许可证开源。

只需打开文件。
```

**What's New in This Version**
```
• 新增 Markdown 格式菜单:粗体(⌘B)和斜体(⌘I)用 Markdown 标记包裹所选文本或移除标记,添加链接(⌘K)用已拷贝的网址把所选文本变成链接。选中文本后输入 *、_、`、~、[、( 或 ",会包裹所选文本而不是替换它
• 在阅读模式中将任务列表拷贝为纯文本时,会得到空框和已勾选框字符,而不是不可见的占位符
• 网址中含有括号的链接(如维基百科)和 README 徽章现在在编辑器中显示为一个完整链接,按住 ⌘ 点按会打开完整网址
• 存储为和复制会保留 .json、.sh 等扩展名和文件权限,私钥的副本仍然只有你能读取
```
