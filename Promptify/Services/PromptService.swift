import Foundation

/// Service for building AI prompts and handling responses
struct PromptService {
    
    static func buildSystemPrompt(bundleID: String?, autoTranslate: Bool, inputText: String, detectedLanguage: String) -> String {
        var base = """
        You are a Prompt Enhancement Assistant. Transform the given text into the best possible prompt for AI communication.

        RULES:
        - Fix grammar, spelling, and clarity issues
        - Make instructions specific and actionable  
        - Add necessary context that's clearly implied
        - Use imperative, direct language
        - Structure complex requests with clear steps
        - If you must ask for clarification, do it in the EXACT same language as the input
        - NEVER respond as if you're the AI being prompted - only enhance the prompt itself
        
        ENHANCEMENT FOCUS:
        - If it's a request: Make it more specific and actionable
        - If it's a question: Make it more precise and complete
        - If it's incomplete: Fill in reasonable details based on context
        - If it's vague: Add specificity while preserving intent
        - If the input is too unclear to enhance: Ask for clarification but ALWAYS in the same language as input
        """
        
        if autoTranslate {
            base += """
            
            TRANSLATION RULE:
            - ALWAYS respond in English, regardless of input language
            - Even if asking for clarification, respond in English
            - Translate all responses to English
            """
        } else {
            base += """
            
            LANGUAGE PRESERVATION RULE:
            - You MUST respond in the same language as the input (\(detectedLanguage))
            - NEVER translate to English or any other language
            - This applies to both enhancements AND clarification requests
            - Language preservation is MANDATORY
            """
        }
        
        if let id = bundleID?.lowercased(), id.contains("cursor") {
            base += """
            
            FOR CURSOR IDE CONTEXTS:
            - Structure as step-by-step development tasks
            - Specify exact files/folders when code changes are implied
            - Include technical requirements and constraints
            - Add relevant context about the codebase when helpful
            """
        }
        
        base += """
        
        OUTPUT FORMAT: Return only the enhanced prompt - nothing else.
        """
        
        return base
    }
    
    static func isAIClarificationRequest(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        let englishIndicators = [
            "please provide more",
            "could you clarify",
            "i need more information",
            "please specify",
            "what specifically",
            "could you be more specific",
            "i'd need more details",
            "please elaborate"
        ]
        
        let turkishIndicators = [
            "daha fazla bilgi",
            "lütfen açıklayın",
            "daha spesifik",
            "detay verebilir",
            "hangi konuda",
            "ne hakkında",
            "daha detaylı",
            "netleştir"
        ]
        
        for indicator in englishIndicators + turkishIndicators {
            if lowercased.contains(indicator) {
                return true
            }
        }
        
        return false
    }
}