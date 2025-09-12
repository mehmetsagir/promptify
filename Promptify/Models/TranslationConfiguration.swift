import Foundation
import SwiftUI

/// Translation settings and language configuration
@MainActor
final class TranslationConfiguration: ObservableObject {
    @Published var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "Turkish" {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage") }
    }
    @Published var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "English" {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    
    init() {
        setupDefaultsIfNeeded()
    }
    
    private func setupDefaultsIfNeeded() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set("Turkish", forKey: "sourceLanguage")
            UserDefaults.standard.set("English", forKey: "targetLanguage")
            
            sourceLanguage = "Turkish"
            targetLanguage = "English"
        }
    }
    
    func buildTranslationPrompt() -> String {
        return """
        You are a Smart Bidirectional Translation Assistant. 
        
        USER'S PREFERRED LANGUAGES: \(sourceLanguage) ↔ \(targetLanguage)
        
        SMART TRANSLATION LOGIC:
        1. First, detect the language of the input text
        2. If the input is in \(sourceLanguage), translate to \(targetLanguage)
        3. If the input is in \(targetLanguage), translate to \(sourceLanguage)
        4. If the input is in neither language, translate to \(targetLanguage) (default)
        
        TRANSLATION RULES:
        - Provide only the translation, no explanations or language detection notes
        - Maintain the original meaning, tone, and style
        - Use natural, fluent language in the target language
        - Preserve formatting (line breaks, punctuation, etc.)
        - Do not add quotes, prefixes, or suffixes to the translation
        
        EXAMPLES:
        - Input in \(sourceLanguage) → Output in \(targetLanguage)
        - Input in \(targetLanguage) → Output in \(sourceLanguage)
        
        OUTPUT: Only the translated text, nothing else.
        """
    }
    
    func detectLanguage(_ text: String) -> String {
        let turkishChars = CharacterSet(charactersIn: "çÇğĞıIİöÖşŞüÜ")
        if text.rangeOfCharacter(from: turkishChars) != nil || 
           text.lowercased().contains("bir") || text.lowercased().contains("bu") || 
           text.lowercased().contains("şey") || text.lowercased().contains("için") {
            return "Turkish"
        }
        return "English"
    }
}