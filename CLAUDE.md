# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is ClawRelay

A Flutter desktop/iOS client that wraps **Claude Code CLI** in a persistent, multi-project chat UI with streaming, thinking visualization, tool-call tracking, and image support. It does not call Anthropic API directly — it talks to a local Go relay (`clawrelay-api` submodule, port 50009) that forks a `claude` CLI subprocess per request and streams output as OpenAI-compatible SSE.

## Build & Development Commands

```bash
flutter pub get                              # Install dependencies
flutter pub run build_runner build           # Regenerate Drift database code (database.g.dart)
flutter run -d macos                         # Run on macOS (also: -d linux, -d windows, -d ios)
flutter build macos --release                # Build release for macOS
flutter analyze                              # Run static analysis (flutter_lints)
flutter test                                 # Run tests
```

After modifying `lib/database/database.dart`, always regenerate with `build_runner`.

## Architecture

```
Flutter Client  ──HTTP/SSE──▶  clawrelay-api (Go :50009)  ──subprocess──▶  claude CLI  ──▶  Anthropic API
```

### State Management (Riverpod)

All state flows through Riverpod providers in `lib/providers/`:

- **`databaseProvider`** — Drift `AppDatabase` singleton, overridden in `main()` via `ProviderScope`
- **`projectsStreamProvider`** — Watches all projects from DB (ordered by `updatedAt DESC`)
- **`selectedProjectIdProvider`** — Currently selected project ID (`StateProvider<int?>`)
- **`unreadProjectIdsProvider`** — In-memory set of project IDs with unread messages
- **`chatProvider(projectId)`** — `AsyncNotifierProvider.family` keyed by project ID; manages `ChatState` (messages, streaming text, thinking, tool calls, error)
- **`serverUrlProvider`** / **`defaultModelProvider`** / **`themeModeProvider`** — Settings persisted via SharedPreferences

### Chat Streaming Flow

`ChatNotifier.sendMessage()` in `chat_provider.dart`:
1. Saves user message to DB, appends to display list
2. Builds `ChatCompletionRequest` with full message history + system prompt + working directory
3. Calls `ClaudeApi.streamChat()` which POSTs to `/v1/chat/completions` and parses SSE
4. Listens for `StreamEvent` variants: `TextDelta` (accumulate text), `ToolUseStart` (collect tool names), `ThinkingDelta` (accumulate reasoning)
5. On completion: saves assistant message to DB, marks other projects as unread

### Database (Drift ORM)

Schema in `lib/database/database.dart`, generated code in `database.g.dart`:

- **Projects** — `id`, `name`, `workingDirectory`, `systemPrompt`, `model` (default: `vllm/claude-sonnet-4-6`), timestamps
- **Messages** — `id`, `projectId` (FK with cascade delete), `role` (user/assistant/system), `content` (plain text or JSON array for multipart with images), timestamp

Key queries: `watchProjects()`, `recentMessagesForProject(id, limit=50)` for display, `messagesForProject(id)` for full API context.

### Message Content Format

- **Text only**: stored as plain string in `content` column
- **With images**: stored as JSON array `[{"type":"text","text":"..."},{"type":"image_url","image_url":{"url":"data:image/...;base64,..."}}]`
- Display code in `MessageBubble` detects format via JSON parse attempt

### SSE Protocol (`lib/services/claude_api.dart`)

Parses line-by-line SSE from the Go relay. Emits sealed `StreamEvent` types:
- Lines starting with `:` → keepalive/comments (skipped)
- `data: [DONE]` → stream end
- `data: {...}` → JSON parsed into `TextDelta`, `ToolUseStart`, or `ThinkingDelta`

## Key Conventions

- **Widget types**: `ConsumerStatefulWidget` when needing local state + providers; `ConsumerWidget` for stateless provider access; plain `StatelessWidget` for pure UI
- **Debug logging**: `debugPrint()` with `[SSE]` / `[PROVIDER]` prefixes
- **Theming**: Material 3 with color seed `0xFF6750A4`, light + dark themes defined in `app.dart`
- **Responsive layout**: `AdaptiveLayout` splits sidebar (200px) + detail; mobile shows sidebar only with navigation
- **Message pagination**: Display last 50 messages; full history sent to API for context

## Platform Support

Desktop: Linux, macOS, Windows. Mobile: iOS. No Android support.
