# PolyChat - iPhone AI Chat Application

An open-source iOS chat application for interacting with AI models via Ollama and other compatible providers.

## Overview

## TestFlight Link 

https://testflight.apple.com/join/VVxXx65X

PolyChat is a native iOS application that provides a seamless chat experience with open source cloud AI models. Unlike proprietary solutions, PolyChat gives you full control over your data and model choices — all conversation data is stored locally on your device.

## Open Source & Sustainability

Poly_Chat is open source and will always have a fully functional free core.

You can:

* Use the app with your own API keys
* Access all essential functionality without paying

To support ongoing development, we plan to introduce optional paid features in the future. These may include:

* Cloud sync and backup
* Hosted infrastructure (for convenience and speed)
* Advanced features (e.g. workflows, agents, websearch, enhanced UI)

Our commitment:
We will never remove core functionality or force payment for basic usage. Paid features will focus on making the experience better — not restricting access.

If you prefer, you will always be able to use Poly_Chat free of charge, leveraging existing free services.


## Features

### AI Providers
- **Ollama**: Connect to remote Ollama instances
- **Configurable API Endpoint**: Connect to any number of OpenAI-compatible APIs

### Chat
- **Multi-turn Conversations**: Full conversation history with context
- **Auto-generated Titles**: LLM-generated contextual conversation names
- **Rename & Delete**: Manage conversations with long-press context menus
- **Message Editing & Retry**: Edit sent messages and regenerate responses
- **Markdown Rendering**: Full markdown with code syntax highlighting and LaTeX/math support

### Models
- **Model Browsing**: Browse available models with detailed capability info
- **Model Comparison**: Side-by-side comparison of two models
- **Starred Models**: Favorite models for quick access
- **Thinking Models**: Extended reasoning traces from models like DeepSeek-R1 and Qwen3

### Attachments & Tools
- **Vision**: Attach and analyze images with vision-capable models
- **PDF Processing**: Attach PDFs up to 50MB with automatic text extraction
- **Web Search**: Tavily API integration for real-time web results (1,000 free searches/month)
- **Tool Use**: Function calling with multi-turn tool loops (up to 3 iterations)
- **Date Tool**: Built-in current date/time context tool

### Customization & Privacy
- **Dark Mode**: Built-in dark mode toggle
- **System Prompt**: Customizable default system prompt for new conversations
- **Privacy First**: All data stored locally
- **Data Export**: Export conversations as JSON
- **Secure Storage**: API keys stored in Keychain

## Technical Architecture

### Core Components
- **SwiftUI**: Modern iOS interface framework
- **ProviderManager**: Routes requests to the active AI provider (Ollama, OpenAI, Grok)
- **OllamaService**: REST API client for Ollama with streaming support
- **ChatManager**: Orchestrates message sending, tool loops, and title generation
- **ModelManager**: Fetches and enriches model metadata, manages favorites
- **WebSearchService**: Tavily API integration for web search tool
- **PDFDocumentService**: PDF text extraction via PDFKit
- **MarkdownWebView**: WKWebView-based renderer with MathJax and code highlighting
- **SecureStorageService**: Keychain wrapper for sensitive credentials
- **LocalStorageService**: Conversation persistence via UserDefaults

### Data Flow
1. User sends message (optionally with image or PDF attachment)
2. `ChatManager` prepares the request and selects the active provider
3. Request sent to provider API (streamed response)
4. If the model calls a tool (`web_search`, `get_current_date`), the tool runs and results are fed back (up to 3 tool iterations)
5. Final response rendered in the chat view with markdown support
6. Conversation title auto-generated from the first exchange (if untitled)
7. Conversation persisted locally (documents deleted if chat deleted)

### Security
- API keys stored in Keychain (not UserDefaults)
- No automatic data sharing with third parties

## Project Structure

```
poly_chat/
├── poly_chat/                # Main source code
│   ├── Models/              # Data models (Conversation, Message, ModelInfo, etc.)
│   ├── Services/            # Business logic (ChatManager, OllamaService, etc.)
│   ├── Views/               # UI components (ChatView, ModelsView, SettingsView, etc.)
│   └── poly_chatApp.swift   # Main app entry point
├── poly_chatTests/          # Unit tests
├── poly_chatUITests/        # UI tests
└── Poly_Chat.xcodeproj/     # Xcode project file
```

## Getting Started

### Prerequisites
- Xcode 15.0 or higher
- A running [Ollama](https://ollama.com) instance (local or remote), or an API key for openAI compatible models

### Installation
1. Clone or download this project
2. Open `Poly_Chat.xcodeproj` in Xcode
3. Select a simulator or connected device
4. Build and run
5. On first launch, configure your provider endpoint and API key in Settings


### Optional: Enable Web Search
Sign up for a free Tavily API key at [tavily.com](https://tavily.com) and add it in Settings to enable the web search tool.

## Testing

### Unit Tests
```bash
xcodebuild test -project Poly_Chat.xcodeproj -scheme poly_chat -destination 'platform=iOS Simulator,name=iPhone 16'
```


### Manual Testing Checklist
1. Launch the app and configure a provider in Settings
2. Create a new conversation and select a model
3. Send a text message and verify streaming response
4. Attach an image (requires a vision-capable model)
5. Attach a PDF and ask a question about its contents
6. Enable web search and ask about a recent event
7. Open Models view and compare two models
8. Export a conversation and verify the JSON output

## Development

### Adding New Features
1. Follow the existing MVVM patterns in `Models/`, `Services/`, `Views/`
2. Route new AI capabilities through `ChatManager`
3. Add new provider support via the `OpenAIBackendAdapter` pattern
4. Add unit tests for new service logic
5. Maintain privacy-focused data handling

### Keeping model data up to date

Model descriptions, capabilities, and specs are stored in `poly_chat/Resources/model_details.json` and bundled at build time. When new models are added to the Ollama cloud API they won't have details until this file is updated.

Use the enrichment script to check for and fill in new models:

```bash
pip install -r scripts/requirements.txt       # one-time setup

python scripts/enrich_model_details.py --dry-run   # preview new models
python scripts/enrich_model_details.py             # write changes
```

Then rebuild. See [`poly_chat/Resources/MODEL_DETAILS_README.md`](poly_chat/Resources/MODEL_DETAILS_README.md) for the full workflow.

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add your changes with tests
4. Submit a pull request

## Troubleshooting

### Cannot connect to Ollama
- Check the endpoint in Settings (default: `http://ollama.com/api`)
- Verify firewall/network settings if using a remote instance

### No models appearing
- For Ollama: pull a model first (`ollama pull llama3`)
- For OpenAI/Grok: verify your API key is set in Settings
- Try pulling the model list manually by tapping the refresh button in Models view

### Keychain errors
- Ensure `Security.framework` is linked in Xcode project settings
- Check signing entitlements

### Web search not working
- Verify the Tavily API key is entered in Settings
- The status indicator in Settings will show if the key is valid
- Free tier allows 1,000 searches/month

## BUGS
 
- [x] starting a new chat while loading


## Roadmap
 
- [x] Model comparison view
- [x] Document (PDF) processing
- [x] Image processing
- [x] markdown
- [x] websearch
- [x] Any OpenAI-compatible API: Configurable endpoint + API key
- [x] stop button (when a model is thinking too long)
- [x] Improve model details page (auto-enrichment script scrapes ollama.com for descriptions, capabilities, context lengths)
- [ ] Way for users to share reviews on models. 
- [ ] Optional backup functionality with encryption
- [ ] some way to understand how the app is being used - to enable data driven development (needs to be transparent and anonymous)
- [ ] Multi-device sync (opt-in)
- [ ] desktop or web version
- [ ] ipad version
- [ ] If app is closed - notification when results arrive
- [ ] premium web search via paid API
- [ ] premium hosted models with faster compute


## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Acknowledgments

- [Ollama](https://ollama.com) for the excellent AI model platform
- [Tavily](https://tavily.com) for the web search API
- [MathJax](https://www.mathjax.org) for LaTeX rendering
- SwiftUI community for the fantastic framework
- All contributors to this project
