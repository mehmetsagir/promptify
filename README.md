# Promptify

A powerful macOS app that enhances your text with AI assistance. Transform ordinary text into well-structured prompts and translate between languages with global keyboard shortcuts.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org/)

## ✨ Features

- **🎯 Prompt Enhancement**: Transform basic text into detailed, effective AI prompts
- **🌐 Smart Translation**: Bidirectional translation between multiple languages  
- **🎤 Voice-to-Text**: Record voice and convert to text using OpenAI Whisper
- **⌨️ Global Hotkeys**: Quick access from anywhere on macOS
- **♿ Accessibility Integration**: Works seamlessly with any text field
- **🔊 Audio Feedback**: Optional sound notifications for better user experience
- **🤖 Multiple AI Models**: Support for GPT-3.5 Turbo, GPT-4, and GPT-4 Turbo

## 📦 Installation

### Option 1: Download Pre-built Release (Recommended)

1. Go to the [Releases page](https://github.com/mehmetsagir/promptify/releases)
2. Download the latest `Promptify.dmg` file
3. Open the DMG and drag Promptify to your Applications folder
4. Launch the app and grant accessibility permissions when prompted

### Option 2: Build from Source

```bash
git clone https://github.com/mehmetsagir/promptify.git
cd promptify
open Promptify.xcodeproj
```

Then build and run in Xcode.

## ⚙️ Requirements

- **macOS**: 12.0 or later
- **OpenAI API Key**: [Get one here](https://platform.openai.com/api-keys)
- **Permissions**: Accessibility access (required for text selection/replacement)
- **Optional**: Input Monitoring (enhanced features)

## 🚀 Setup

1. **Install the App**: Download and install from the releases page or build from source
2. **Grant Permissions**: Allow accessibility access in System Settings when prompted
3. **Add API Key**: Open Settings and add your OpenAI API key
4. **Configure Shortcuts**: Set up your preferred keyboard shortcuts

## 📖 Usage

### Prompt Enhancement
1. Select text in any application
2. Press your configured hotkey (default: ⌥⌘K)
3. The enhanced prompt replaces your selected text

### Translation
1. Enable translation in Settings
2. Select text to translate
3. Press the translation hotkey (default: ⌥⌘T)
4. Text is automatically translated based on detected language

### Voice Input
1. Configure voice hotkeys in Settings
2. Press and hold the voice enhancement/translation hotkey
3. Speak your text
4. Release to process and insert the enhanced/translated result

## 🛠️ Development

### Project Structure

```
Promptify/
├── Promptify/
│   ├── Models/              # Data models and configuration
│   │   ├── AppConfiguration.swift
│   │   ├── HotkeyConfiguration.swift
│   │   └── TranslationConfiguration.swift
│   ├── Services/            # Business logic services
│   │   ├── PromptService.swift
│   │   └── OpenAIClient.swift
│   ├── Utilities/           # Helper utilities
│   │   ├── ClipboardHelper.swift
│   │   ├── KeychainHelper.swift
│   │   └── Permission.swift
│   ├── UI/                  # User interface components
│   │   ├── HUD.swift
│   │   ├── SettingsWindow.swift
│   │   └── HotkeyRecorder.swift
│   └── Core/                # Core app files
│       ├── AppState.swift
│       ├── PromptifyApp.swift
│       └── VoiceRecordingManager.swift
├── Tests/                   # Unit and UI tests
└── Resources/               # Assets and resources
```

### Building

1. Clone the repository
2. Open `Promptify.xcodeproj` in Xcode 14+
3. Build and run the project

### Dependencies

- [HotKey](https://github.com/soffes/HotKey) - Global hotkey management
- Native macOS APIs for accessibility, clipboard, and system integration

## 🔒 Privacy

- **Local Processing**: All text processing is done via OpenAI's API
- **Secure Storage**: API keys are stored securely in macOS Keychain
- **No Tracking**: No analytics, telemetry, or user tracking
- **No Data Storage**: No user data is stored locally or transmitted elsewhere

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Swift conventions and best practices
- Write clear, self-documenting code
- Add tests for new features
- Update documentation as needed
- Ensure accessibility compliance

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [OpenAI](https://openai.com/) for the GPT and Whisper APIs
- [HotKey](https://github.com/soffes/HotKey) library for global hotkey support
- The Swift and macOS developer communities

## 🐛 Bug Reports & Feature Requests

If you encounter any issues or have feature requests, please:

1. Check the [Issues](https://github.com/mehmetsagir/promptify/issues) page first
2. Create a new issue with detailed information
3. Include your macOS version and steps to reproduce

## 📊 Changelog

See [Releases](https://github.com/mehmetsagir/promptify/releases) for version history and changes.