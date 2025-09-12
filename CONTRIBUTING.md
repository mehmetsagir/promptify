# Contributing to Promptify

Thank you for your interest in contributing to Promptify! We welcome contributions from the community and appreciate your help in making this project better.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it to understand the standards of behavior we expect.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the [existing issues](https://github.com/mehmetsagir/promptify/issues) to avoid duplicates.

When filing a bug report, please include:

- **Clear title and description** of the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs. actual behavior  
- **macOS version** and Promptify version
- **Screenshots** if applicable
- **Console logs** if relevant

### Suggesting Features

We love feature suggestions! Please:

1. Check existing feature requests first
2. Use the feature request template
3. Provide clear use cases and benefits
4. Consider implementation complexity

### Pull Requests

1. **Fork** the repository
2. **Create a branch** for your feature/fix:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes** following our coding standards
4. **Test your changes** thoroughly
5. **Commit your changes** with clear messages:
   ```bash
   git commit -m "Add amazing feature"
   ```
6. **Push to your fork**:
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Create a Pull Request** with:
   - Clear title and description
   - Reference to related issues
   - Screenshots/recordings for UI changes
   - Testing notes

## Development Setup

### Prerequisites

- **Xcode 14+** with Swift 5.5+
- **macOS 12.0+** for development
- **OpenAI API key** for testing

### Setup Steps

1. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/promptify.git
   cd promptify
   ```

2. Open the project:
   ```bash
   open Promptify.xcodeproj
   ```

3. Build and run the project in Xcode

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use **4 spaces** for indentation (not tabs)
- **Line length**: 120 characters maximum
- **Naming**: Use descriptive names for variables and functions

### Code Organization

- **Group related code** into logical files and folders
- **Use MARK comments** to organize code sections
- **Follow the existing project structure**:
  ```
  Models/         # Data models and configuration
  Services/       # Business logic services  
  Utilities/      # Helper utilities
  UI/            # User interface components
  Core/          # Core application files
  ```

### Documentation

- **Document public APIs** with clear comments
- **Use meaningful commit messages**
- **Update README** for new features
- **Add code comments** for complex logic

### Testing

- **Write unit tests** for new functionality
- **Test on different macOS versions** when possible
- **Verify accessibility** features work correctly
- **Test with various OpenAI models**

## Project Architecture

### Key Components

- **AppState**: Main application state coordinator
- **AppConfiguration**: User defaults and settings management
- **HotkeyConfiguration**: Global hotkey management
- **TranslationConfiguration**: Translation settings
- **PromptService**: AI prompt building logic
- **OpenAIClient**: API communication
- **VoiceRecordingManager**: Voice input handling

### Dependencies

- **HotKey**: Global hotkey management (external)
- **Native macOS APIs**: Accessibility, clipboard, system integration

## Review Process

1. **Automated checks** must pass (building, basic tests)
2. **Code review** by maintainers
3. **Testing** on different configurations
4. **Documentation** updates if needed
5. **Merge** when approved

## Getting Help

- **Discord**: [Join our community](#) (coming soon)
- **Issues**: Use GitHub issues for questions
- **Email**: Contact maintainers for security issues

## Recognition

Contributors will be recognized in:
- README acknowledgments
- Release notes for significant contributions
- GitHub contributors list

## License

By contributing to Promptify, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Thank you for contributing to Promptify! 🚀