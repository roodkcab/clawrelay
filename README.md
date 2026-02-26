# ClawRelay

**English** | [中文](#中文)

---

A Flutter desktop client that turns **Claude Code** into a persistent, multi-project chat interface — with real-time streaming, thinking visualization, tool-call tracking, and image support.

## What is ClawRelay?

Claude Code is Anthropic's agentic CLI that can read files, run commands, and write code autonomously. ClawRelay is an **orchestration layer** that wraps Claude Code in a polished desktop UI so you can:

- Maintain **multiple independent projects**, each with its own working directory, model, and system prompt
- Watch Claude **think and use tools** in real time as it processes your requests
- Send **images** via paste, drag-drop, or file picker
- Keep full **chat history** locally in SQLite across sessions

ClawRelay does not call the Anthropic API directly. It talks to a local Go relay ([`clawrelay-api`](https://github.com/roodkcab/clawrelay-api)) that forks a `claude` CLI process per request, streams the output back as OpenAI-compatible SSE, and cleans up when done. This means Claude's full tool ecosystem (Bash, file editing, web search, MCP servers, etc.) is available in every conversation.

## Architecture

```
ClawRelay (Flutter)
    │
    │  HTTP / SSE (OpenAI-compatible)
    ▼
clawrelay-api (Go · :50009)
    │
    │  subprocess
    ▼
claude CLI (Claude Code)
    │
    │  Anthropic API
    ▼
Claude (Sonnet / Opus / Haiku)
```

## Features

### Projects
- Create multiple independent projects, each with its own:
  - Model (Sonnet / Opus / Haiku)
  - System prompt
  - Working directory — Claude starts here and loads `CLAUDE.md` + memory
- Edit or delete projects at any time
- Unread dot badge on the sidebar when a response arrives while you are in another project

### Chat
- **Streaming output** — tokens appear as Claude generates them
- **Markdown rendering** — code blocks, tables, lists rendered once streaming finishes; plain text during streaming to avoid parser crashes
- **Stop button** — cancels the active stream immediately
- **Pagination** — displays the latest 50 messages; full history still passed as API context
- **Auto-scroll** — stays pinned to the bottom during streaming; respects manual scroll position if you scroll up; re-pins when you scroll back down

### Thinking (Extended Thinking models)
- Live preview panel while Claude reasons internally
- Collapsed (last ~120 chars) by default; tap to expand the full chain-of-thought
- Disappears cleanly once the final answer begins

### Tool Calls
- Chip badges appear below the message as Claude invokes tools (Bash, Edit, Read, WebSearch, etc.)
- Detected from both streaming `content_block_start` events and summary `type: assistant` events as fallback
- Each tool name appears only once (deduplicated)

### Image Attachments
- **File picker** — browse and select one or more images
- **Ctrl+V** — paste an image from the system clipboard
- **Drag and drop** — drop image files onto the input card
- Thumbnail strip with × remove buttons before sending
- Images sent as base64 data URIs; the relay saves them to `/tmp/` and passes paths to Claude's Read tool
- Inline rendering in chat history (max 320×320, rounded corners)

### Input UX
- **Enter** sends; **Shift+Enter** inserts a newline
- Card-style input area with toolbar (attach / send) on top and a multi-line textarea below

### Appearance
- Light / System / Dark theme — persisted across restarts

## Project Structure

```
lib/
├── main.dart                    Entry point, Riverpod overrides
├── app.dart                     MaterialApp, light + dark themes
├── screens/
│   ├── home_screen.dart         Split-view: project sidebar + chat
│   ├── chat_screen.dart         Message list, streaming, auto-scroll
│   ├── project_form_screen.dart Create / edit project
│   └── settings_screen.dart    Server URL, model, theme
├── widgets/
│   ├── message_bubble.dart      Renders one message (text, images, thinking, chips)
│   ├── chat_input.dart          Input card with image attachment + drag-drop
│   ├── project_tile.dart        Sidebar item with unread badge
│   └── adaptive_layout.dart    Responsive sidebar / detail split
├── providers/
│   ├── chat_provider.dart       Streaming state, send/cancel, history
│   ├── projects_provider.dart   CRUD + unread tracking
│   ├── settings_provider.dart   Server URL, model, theme mode
│   └── database_provider.dart  Drift DB singleton
├── services/
│   ├── claude_api.dart          HTTP/SSE client, StreamEvent parser
│   └── settings_service.dart   SharedPreferences wrapper
├── models/
│   └── api_types.dart           ChatMessage, ImageAttachment, StreamEvent (sealed)
└── database/
    ├── database.dart            Drift schema: Projects + Messages
    └── database.g.dart          Generated code
```

## Getting Started

### Prerequisites

- Flutter 3.19 or later
- Linux: `libsqlite3-dev`
- Windows: Visual Studio 2022 with **Desktop development with C++**
- macOS: Xcode command-line tools

### Run

```bash
flutter pub get
flutter run -d linux      # or -d windows / -d macos
```

### Build

```bash
flutter build linux --release
# Binary: build/linux/x64/release/bundle/clawrelay
```

```
flutter build windows --release
# Binary: build\windows\x64\runner\Release\clawrelay.exe
```

### Connect to the backend

Open **Settings** (gear icon, bottom of sidebar) and set **Server URL** to wherever `claude-stream-api` is running:

```
http://<server-ip>:50009
```

Default is `http://localhost:50009`.

## Backend (clawrelay-api)

The Go relay server lives in a separate repository, included here as a Git submodule at `clawrelay-api/`.

Repository: **[github.com/roodkcab/clawrelay-api](https://github.com/roodkcab/clawrelay-api)**

Key points:
- Port **50009**
- OpenAI-compatible `/v1/chat/completions` with SSE streaming
- Forks one `claude` CLI process per request; `--max-turns 0` (single turn, no autonomous loop by default)
- Working directory passed from the Flutter client so Claude loads the right `CLAUDE.md` and memory
- Images decoded from base64 → `/tmp/claude-img-*.ext` → injected as `[Image: path]` in prompt → cleaned up after response

### Clone including the backend

```bash
git clone --recurse-submodules https://github.com/roodkcab/clawrelay.git
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### Build and run the relay

```bash
cd clawrelay-api
go build -o clawrelay-api .
HTTP_PROXY=http://... HTTPS_PROXY=http://... ./clawrelay-api
```

Or on a remote Linux server (background):

```bash
nohup ./clawrelay-api > clawrelay-api.log 2>&1 &
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `drift` + `sqlite3_flutter_libs` | Local SQLite database |
| `flutter_markdown` | Markdown rendering |
| `shared_preferences` | Settings persistence |
| `desktop_drop` | Drag-drop image input |
| `file_picker` | File browser for image selection |
| `http` | HTTP / SSE streaming client |

---

# 中文

**[English](#clawrelay)** | 中文

---

ClawRelay 是一个基于 Flutter 的桌面客户端，将 **Claude Code** 封装为一个持久化、多项目的对话界面，支持实时流式输出、思维过程可视化、工具调用追踪和图片输入。

## 这是什么？

Claude Code 是 Anthropic 开发的智能体 CLI，能够读写文件、执行命令、自主编写代码。ClawRelay 是其**编排层（Orchestrator）**，为其提供完整的桌面 UI，使你可以：

- 管理**多个独立项目**，每个项目有独立的工作目录、模型配置和系统提示词
- 实时观察 Claude **思考过程和工具调用**
- 通过粘贴、拖拽或文件选择上传**图片**
- 将完整的**对话历史**持久化存储于本地 SQLite

ClawRelay 不直接调用 Anthropic API，而是通过本地 Go 中继服务（[`clawrelay-api`](https://github.com/roodkcab/clawrelay-api)）转发请求：每次对话时启动一个 `claude` CLI 子进程，将流式输出以 OpenAI 兼容的 SSE 格式回传，结束后自动清理。因此，Claude 的全套工具生态（Bash、文件编辑、网络搜索、MCP 服务器等）均可在对话中使用。

## 系统架构

```
ClawRelay（Flutter 桌面端）
    │
    │  HTTP / SSE（兼容 OpenAI 格式）
    ▼
clawrelay-api（Go 中继 · 端口 50009）
    │
    │  子进程
    ▼
claude CLI（Claude Code）
    │
    │  Anthropic API
    ▼
Claude（Sonnet / Opus / Haiku）
```

## 功能特性

### 项目管理
- 创建多个独立项目，每个项目拥有独立的：
  - 模型选择（Sonnet / Opus / Haiku）
  - 系统提示词
  - 工作目录 — Claude 将在该目录下启动，并自动加载 `CLAUDE.md` 和记忆文件
- 支持随时编辑或删除项目
- 在其他项目有新回复时，侧边栏对应项目显示未读红点

### 对话
- **流式输出** — 文字随 Claude 生成实时出现
- **Markdown 渲染** — 流式结束后渲染代码块、表格、列表等；流式过程中显示纯文本以避免解析器崩溃
- **停止按钮** — 流式过程中立即取消当前响应
- **分页加载** — 打开会话时加载最近 50 条消息，API 上下文仍使用完整历史
- **自动吸底** — 流式过程中自动滚动到最新内容；手动上滑后停止吸底；滑回底部后自动恢复

### 思维过程（扩展思考模型）
- 流式过程中实时显示 Claude 的内部推理过程
- 默认折叠（显示最后约 120 个字符），点击展开完整思维链
- 最终回复开始后自动隐藏

### 工具调用
- Claude 调用工具时（Bash、Edit、Read、WebSearch 等）在消息下方显示 Chip 标签
- 同时检测流式 `content_block_start` 事件和汇总型 `type: assistant` 事件（兜底策略）
- 自动去重，每个工具名称只显示一次

### 图片支持
- **文件选择** — 点击附件按钮浏览并选择图片
- **Ctrl+V** — 直接从系统剪贴板粘贴图片
- **拖拽上传** — 将图片文件拖入输入框区域
- 发送前可在缩略图条中预览并删除
- 图片以 base64 data URI 发送；中继服务保存为临时文件并注入提示词，响应结束后自动清理
- 聊天历史中内联显示（最大 320×320，圆角）

### 输入体验
- **Enter** 发送，**Shift+Enter** 换行
- 卡片式输入区，顶部工具栏（附件 / 发送），下方为多行文本域

### 外观
- 亮色 / 跟随系统 / 暗色主题，设置跨重启持久化

## 快速开始

### 环境要求

- Flutter 3.19 或更高版本
- Linux：需安装 `libsqlite3-dev`
- Windows：Visual Studio 2022，包含 **使用 C++ 的桌面开发** 工作负载
- macOS：Xcode 命令行工具

### 运行

```bash
flutter pub get
flutter run -d linux    # 或 -d windows / -d macos
```

### 构建

```bash
# Linux
flutter build linux --release

# Windows
flutter build windows --release
```

### 连接后端

打开**设置**（侧边栏底部齿轮图标），将 **Server URL** 修改为 `claude-stream-api` 所在机器的地址：

```
http://<服务器IP>:50009
```

默认值为 `http://localhost:50009`。

## 后端（clawrelay-api）

Go 中继服务以 Git Submodule 方式包含在本仓库的 `clawrelay-api/` 目录下。

仓库地址：**[github.com/roodkcab/clawrelay-api](https://github.com/roodkcab/clawrelay-api)**

核心说明：
- 监听端口 **50009**
- 提供 OpenAI 兼容的 `/v1/chat/completions` SSE 接口
- 每次请求启动一个 `claude` CLI 子进程；`--max-turns 0`（单轮，不开启自主循环）
- 工作目录由 Flutter 端传入，Claude 可加载对应项目的 `CLAUDE.md` 和记忆文件
- 图片解码为临时文件注入提示词，响应结束后自动清理

### 克隆时包含后端

```bash
git clone --recurse-submodules https://github.com/roodkcab/clawrelay.git
```

若已克隆但未拉取子模块：

```bash
git submodule update --init --recursive
```

### 构建并启动中继服务

```bash
cd clawrelay-api
go build -o clawrelay-api .
HTTP_PROXY=http://... HTTPS_PROXY=http://... ./clawrelay-api
```

后台运行（Linux 服务器）：

```bash
nohup ./clawrelay-api > clawrelay-api.log 2>&1 &
```
