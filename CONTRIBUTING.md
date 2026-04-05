# Contributing to PolyChat

Thank you for your interest in contributing to PolyChat!

## Getting Started

### Prerequisites
- Xcode 15.0 or higher
- A running [Ollama](https://ollama.com) instance (local or remote) for testing AI features
- Optional: OpenAI or Grok API key for testing those providers

### Setup
1. Fork the repository and clone your fork
2. Open `Poly_Chat.xcodeproj` in Xcode
3. Select a simulator or connected device
4. Build and run (`Cmd+R`)
5. Configure a provider endpoint in Settings on first launch

## How to Contribute

### Reporting Bugs
Open an issue with:
- iOS/Xcode version
- Steps to reproduce
- Expected vs actual behavior
- Logs or screenshots if relevant

### Suggesting Features
Open an issue describing the feature and the problem it solves. Check the roadmap in the README first — some features are already planned.

### Submitting Code

1. **Fork** the repository
2. **Create a branch** from `main`: `git checkout -b feature/my-feature`
3. **Write your changes** following the patterns below
4. **Test** your changes (see Testing section)
5. **Submit a pull request** targeting `main`

Keep PRs focused — one feature or fix per PR. Larger changes should be discussed in an issue first.

## Code Style & Patterns

- Follow existing **MVVM structure**: `Models/`, `Services/`, `Views/`
- Route new AI capabilities through `ChatManager`
- Add new provider support via the `BackendAdapter` protocol (see `OpenAIBackendAdapter.swift`)
- Store sensitive data (API keys) via `SecureStorageService`, never `UserDefaults`
- Keep UI in SwiftUI; use UIKit wrappers only where SwiftUI lacks support
- No third-party Swift dependencies — the project intentionally has no Swift Package dependencies beyond the standard library

## Testing

Run unit tests before submitting:
```bash
xcodebuild test -project Poly_Chat.xcodeproj -scheme poly_chat -destination 'platform=iOS Simulator,name=iPhone 16'
```

For significant changes, also run through the manual checklist in the README.

## Licensing & CLA

By submitting a pull request, you agree that your contribution is licensed under the [Apache License 2.0](LICENSE).

For contributions that may be used in commercial/premium features, you may be asked to sign a Contributor License Agreement (CLA). This will be noted in the PR review if required.

## Core vs Premium

PolyChat uses an open core model. The free core (this repository) will always be fully functional. Premium features (cloud sync, hosted infrastructure, etc.) are developed separately. Please do not add StoreKit, subscription, or payment logic to this repository — those belong in the premium module.
