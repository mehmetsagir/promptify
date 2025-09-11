# Promptify

A powerful macOS app that enhances your text with AI assistance. Transform ordinary text into well-structured prompts and translate between languages with keyboard shortcuts.

## Features

- **Prompt Enhancement**: Transform basic text into detailed, effective AI prompts
- **Translation**: Bidirectional translation between multiple languages
- **Global Hotkeys**: Quick access from anywhere on macOS
- **Accessibility Integration**: Works seamlessly with any text field
- **Multiple AI Models**: Support for GPT-3.5 Turbo, GPT-4, and GPT-4 Turbo

## Download

### Direct Download (Recommended)
1. Go to the [Releases page](https://github.com/mehmetsagir/promptify/releases)
2. Download the latest `Promptify.dmg` file
3. Open the DMG and drag Promptify to your Applications folder
4. Launch the app and grant accessibility permissions when prompted

### Requirements
- macOS 12.0 or later
- OpenAI API key ([get one here](https://platform.openai.com))

### Note on Code Signing
The releases are built unsigned for broader compatibility. macOS will show a security warning on first launch:
1. Right-click the app and select "Open" instead of double-clicking
2. Click "Open" in the security dialog
3. Grant accessibility permissions when prompted

## Setup

1. **Install the App**: Download and install from the releases page
2. **Grant Permissions**: Allow accessibility access in System Settings when prompted
3. **Add API Key**: Open Settings and add your OpenAI API key
4. **Configure Shortcuts**: Set up your preferred keyboard shortcuts

## Usage

### Prompt Enhancement
1. Select text in any application
2. Press your configured hotkey (default: ⌥⌘K)
3. The enhanced prompt replaces your selected text

### Translation
1. Enable translation in Settings
2. Select text to translate
3. Press the translation hotkey (default: ⌥⌘T)
4. Text is automatically translated based on detected language

## Settings

The app is organized into three settings tabs:

- **General**: AI model selection, API key configuration, and basic settings
- **Enhancement**: Keyboard shortcuts and prompt enhancement options
- **Translation**: Translation settings, language selection, and translation shortcuts

## Privacy

- All text processing is done via OpenAI's API
- No data is stored locally except for your API key (securely in Keychain)
- No analytics or tracking

## Building from Source

If you prefer to build the app yourself:

```bash
git clone https://github.com/mehmetsagir/promptify.git
cd promptify
open Promptify.xcodeproj
```

Then build and run in Xcode.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.