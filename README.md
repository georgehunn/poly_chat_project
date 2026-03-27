# OpenChat - iPhone AI Chat Application ✅

An open-source ChatGPT-like application for iPhone that integrates with Ollama and other AI providers.

**Status: Ready for Testing!** All compilation issues have been resolved.

## Overview

OpenChat is a native iOS application that provides a seamless chat experience with locally-hosted AI models through Ollama. Unlike proprietary solutions, OpenChat gives you full control over your data and model choices.

## Features

- 🤖 **Ollama Integration**: Connect to local or remote Ollama instances with full conversation history support
- 💬 **Chat Interface**: Modern, intuitive chat interface similar to ChatGPT with multi-turn conversation support
- 🧠 **Model Selection**: Browse and select from available AI models
- 👥 **Personalized Chats**: Each conversation gets a unique name from random boy/girl name lists
- 🏷️ **Model Information**: View which AI model is being used in each conversation
- ✏️ **Rename Conversations**: Long press to rename conversations to your preference
- 🌙 **Dark Mode**: Built-in dark mode support
- 🔒 **Privacy First**: All data stored locally on your device
- 📤 **Data Export**: Export conversations as JSON
- ⚙️ **Full Settings**: Customize your experience

## Technical Architecture

### Core Components
- **SwiftUI**: Modern iOS interface framework
- **Ollama API**: REST API integration for AI model access
- **Keychain**: Secure storage for API keys and sensitive data
- **UserDefaults**: Local storage for conversations and settings

### Data Flow
1. User sends message through UI
2. Message routed through ChatManager
3. Request sent to Ollama API
4. Response streamed back to UI
5. Conversation persisted locally

### Security
- API keys stored in Keychain (secure enclave)
- Conversation data encoded in UserDefaults
- No automatic data sharing with third parties

## Project Structure

```
open_chat/
├── open_chat/                 # Main source code
│   ├── Models/               # Data models (Conversation, Message, etc.)
│   ├── Services/             # Business logic (ChatManager, OllamaService)
│   ├── Views/                # UI components (ContentView, ChatView, etc.)
│   └── open_chatApp.swift    # Main app entry point
├── open_chatTests/           # Unit tests
├── open_chatUITests/         # UI tests
└── open_chat.xcodeproj/      # Xcode project file
```

## Getting Started

### Prerequisites
1. Xcode 14.0 or higher
2. Ollama installed locally (`brew install ollama`)
3. At least one model pulled (`ollama pull llama3`)

### Installation
1. Clone or download this project
2. Open `open_chat.xcodeproj` in Xcode
3. Add Security.framework to your project (see XCODE_SETUP.md)
4. **IMPORTANT**: All compilation issues have been resolved! ✅
5. Select a simulator or connected device
6. Press Cmd+R to build and run

### Running Ollama
```bash
# Start Ollama service
ollama serve

# Pull a model to test with
ollama pull llama3
```

## Testing

### Unit Tests
Run unit tests by pressing Cmd+U in Xcode or:
```bash
# In Xcode, go to Product → Test
# Or use xcodebuild:
xcodebuild test -project open_chat.xcodeproj -scheme open_chat -destination 'platform=iOS Simulator,name=iPhone 14'
```

### Manual Testing
1. Launch the app in simulator
2. Create a new conversation
3. Select a model
4. Send a message
5. Verify response from Ollama
6. Test settings and data management features

## Development

### Adding New Features
1. Follow the existing patterns in Models/Services/Views
2. Add unit tests for new functionality
3. Ensure proper error handling
4. Maintain privacy-focused data handling

### Contributing
1. Fork the repository
2. Create a feature branch
3. Add your changes
4. Write tests
5. Submit a pull request

## Troubleshooting

### Common Issues

1. **Cannot connect to Ollama**
   - Ensure Ollama is running (`ollama serve`)
   - Check endpoint in Settings (should be http://localhost:11434)
   - Verify firewall settings

2. **No models appearing**
   - Pull a model: `ollama pull llama3`
   - Restart the app

3. **Keychain errors**
   - Ensure Security.framework is added to the project
   - Check entitlements

4. **App Icon Issues**
   - The app now includes all required icons including the 1024x1024 PNG for App Store submission
   - If you encounter icon-related build errors, verify the Contents.json file in AppIcon.appiconset includes filename references

## Roadmap

- [ ] Enhanced model comparison features
- [ ] Document processing capabilities
- [ ] Voice input/output
- [ ] Multi-device sync (opt-in)
- [ ] Plugin architecture for other AI providers

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Ollama team for the excellent local AI model platform
- SwiftUI community for the fantastic framework
- All contributors to this project