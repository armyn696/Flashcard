import Foundation
import UIKit

class GeminiAPI {
    static let shared = GeminiAPI()
    private let apiKey: String
    private let model = "gemini-2.0-flash"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
    
    private init() {
        // Use the API key provided directly by the user
        self.apiKey = "AIzaSyAy-cFfKeh_LTviVgIOvF3ZiUEDmdFYmyQ"
    }
    
    func generateFlashcards(from text: String, completion: @escaping (Result<[Flashcard], Error>) -> Void) {
        let urlString = "\(endpoint)\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        let prompt = """
        You are an AI assistant specializing in creating educational flashcards from text. Your task is to generate flashcard content based on the provided 'Context Text'.

        **Core Instructions:**

        1. **Language Detection:** Analyze the language of the 'Context Text'. All generated questions and answers MUST be in the **same language** as the context.
        2. **Generate Two Types of Flashcards:**
           * **Type 1: Standard Question & Answer:**
               * **Question:** Generate a clear, complete, and understandable question based on the text. The question should not be too short or ambiguous; ensure the user knows what information is being sought. End the question with a question mark (?).
               * **Answer:** Provide a VERY CONCISE answer to the question. Aim for under 15 words, focusing on the key fact, definition, term, date, etc. This answer needs to be suitable for quick recall.
           * **Type 2: Fill-in-the-Blank:**
               * **Question:** Create a sentence based on the context text where a key term, concept, or piece of information is replaced by '__________' (a blank). The sentence should provide enough context for the user to figure out the missing word(s).
               * **Answer:** Provide ONLY the word(s) that were removed to create the blank. This answer should also be concise.
        
        **IMPORTANT: NEVER truncate any questions or answers. Do not use ellipses (...) at the end of any text. All questions and answers must be complete and not cut off.**

        Context Text:
        ---
        \(text)
        ---

        Respond in JSON format as an array of objects with "question" and "answer" fields only. The array should include both standard Q&A cards and fill-in-the-blank cards.
        """
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data, let text = String(data: data, encoding: .utf8), !data.isEmpty else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: 0, userInfo: [NSLocalizedDescriptionKey: "The data couldn't be read because it is missing!"]))) }
                return
            }
            print("\n--- Gemini API RAW RESPONSE ---\n\(text)\n-------------------------------\n")
            // Parse the Gemini API response
            do {
                // Parse the top-level JSON
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let part = parts.first,
                   let markdownText = part["text"] as? String {
                    // Extract JSON from markdown code block
                    let jsonString: String
                    if markdownText.contains("```json") {
                        jsonString = markdownText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if markdownText.contains("```") {
                        jsonString = markdownText.replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        jsonString = markdownText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    print("\n--- Extracted JSON ---\n\(jsonString)\n---------------------\n")
                    if let jsonData = jsonString.data(using: .utf8) {
                        struct QuestionAnswer: Decodable { let question: String; let answer: String }
                        let qaPairs = try JSONDecoder().decode([QuestionAnswer].self, from: jsonData)
                        let cards = qaPairs.map { Flashcard(id: UUID(), question: $0.question, answer: $0.answer) }
                        DispatchQueue.main.async { completion(.success(cards)) }
                        return
                    } else {
                        throw NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert extracted JSON string to data."])
                    }
                }
                throw NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not extract flashcards JSON from response."])
            } catch {
                print("JSON decode error: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }
    
    /// Generate flashcards from an image by sending it directly to the Gemini API
    func generateFlashcards(from image: UIImage, completion: @escaping (Result<[Flashcard], Error>) -> Void) {
        let urlString = "\(endpoint)\(model):generateContent?key=\(apiKey)"
        print("[GeminiAPI] generateFlashcards(from image:): URL = \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[GeminiAPI] Invalid URL: \(urlString)")
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("[GeminiAPI] Failed to convert UIImage to JPEG data")
            completion(.failure(NSError(domain: "ImageConversionFailed", code: 0)))
            return
        }
        let base64Image = data.base64EncodedString()
        let prompt = """
        You are an AI assistant specializing in creating educational flashcards from images. Your task is to generate flashcard content based on the provided image.

        **Core Instructions:**

        1. **Language Detection:** Analyze the language in the image. All generated questions and answers MUST be in the **same language** as the content in the image.
        2. **Generate Two Types of Flashcards:**
           * **Type 1: Standard Question & Answer:**
               * **Question:** Generate a clear, complete, and understandable question based on the image content. The question should not be too short or ambiguous; ensure the user knows what information is being sought. End the question with a question mark (?).
               * **Answer:** Provide a VERY CONCISE answer to the question. Aim for under 15 words, focusing on the key fact, definition, term, date, etc. This answer needs to be suitable for quick recall.
           * **Type 2: Fill-in-the-Blank:**
               * **Question:** Create a sentence based on the image content where a key term, concept, or piece of information is replaced by '__________' (a blank). The sentence should provide enough context for the user to figure out the missing word(s).
               * **Answer:** Provide ONLY the word(s) that were removed to create the blank. This answer should also be concise.
        
        **IMPORTANT: NEVER truncate any questions or answers. Do not use ellipses (...) at the end of any text. All questions and answers must be complete and not cut off.**

        Respond in JSON format as an array of objects with "question" and "answer" fields only. The array should include both standard Q&A cards and fill-in-the-blank cards.
        """
        let body: [String: Any] = [
            "contents": [[
                "role": "user",
                "parts": [
                    [
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ],
                    ["text": prompt]
                ]
            ]]
        ]
        if let bodyData = try? JSONSerialization.data(withJSONObject: body),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[GeminiAPI] Request body: \(bodyString.prefix(200))... (truncated)")
        } else {
            print("[GeminiAPI] Failed to serialize request body")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[GeminiAPI] Network error: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[GeminiAPI] HTTP status: \(httpResponse.statusCode)")
            }
            guard let data = data else {
                print("[GeminiAPI] No data returned from Gemini API")
                DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data returned from Gemini API"]))) }
                return
            }
            if let text = String(data: data, encoding: .utf8) {
                print("[GeminiAPI] Raw response: \n\(text)")
            } else {
                print("[GeminiAPI] Could not decode response data as UTF-8 string")
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let part = parts.first,
                   let text = part["text"] as? String {
                    print("[GeminiAPI] Extracted text: \(text)")
                    let jsonString = text
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    print("[GeminiAPI] JSON to decode: \(jsonString)")
                    if let jsonData = jsonString.data(using: .utf8) {
                        struct QA: Decodable { let question: String; let answer: String }
                        do {
                            let qa = try JSONDecoder().decode([QA].self, from: jsonData)
                            let cards = qa.map { Flashcard(id: UUID(), question: $0.question, answer: $0.answer) }
                            print("[GeminiAPI] Decoded flashcards: \(cards.map { $0.question })")
                            DispatchQueue.main.async { completion(.success(cards)) }
                            return
                        } catch {
                            print("[GeminiAPI] JSON decode error: \(error)")
                        }
                    }
                }
                print("[GeminiAPI] Could not parse flashcards JSON from Gemini API response.")
                if let text = String(data: data, encoding: .utf8) {
                    print("[GeminiAPI] Final fallback raw response: \n\(text)")
                }
                DispatchQueue.main.async { completion(.failure(NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse flashcards JSON"])))}
            } catch {
                print("[GeminiAPI] Exception during parsing: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
    }
    
    /// Evaluate user's answer correctness and return a percentage score via API
    func evaluateAnswer(userAnswer: String, correctAnswer: String) async -> Double {
        // Use local scoring for faster response
        return localScoring(userAnswer: userAnswer, correctAnswer: correctAnswer)
    }
    
    /// Simple local scoring based on word overlap
    private func simpleLocalScore(correct: String, userAnswer: String) -> Int {
        let sep: (Character) -> Bool = { !$0.isLetter }
        let corrWords = Set(correct.lowercased().split(whereSeparator: sep))
        let userWords = Set(userAnswer.lowercased().split(whereSeparator: sep))
        guard !corrWords.isEmpty else { return 0 }
        let overlap = corrWords.intersection(userWords).count
        let score = Int(Double(overlap) / Double(corrWords.count) * 100)
        return min(max(score, 0), 100)
    }
    
    private func localScoring(userAnswer: String, correctAnswer: String) -> Double {
        // If either answer is empty, return 0
        guard !userAnswer.isEmpty, !correctAnswer.isEmpty else {
            return 0.0
        }
        
        // Normalize both answers: trim whitespace, convert to lowercase
        let normalizedUserAnswer = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCorrectAnswer = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // If answers are identical after normalization, return 1.0 (perfect match)
        if normalizedUserAnswer == normalizedCorrectAnswer {
            return 1.0
        }
        
        // For very short answers (1-3 words), use stricter matching
        let userWordCount = normalizedUserAnswer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        let correctWordCount = normalizedCorrectAnswer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        
        if userWordCount <= 3 && correctWordCount <= 3 {
            // For short phrases, if one contains the other completely, consider it a good match
            if normalizedUserAnswer.contains(normalizedCorrectAnswer) || normalizedCorrectAnswer.contains(normalizedUserAnswer) {
                return 0.9 // 90% match for short phrases that contain each other
            }
            
            // For single words with similar characters (allow for accents and small typos)
            if userWordCount == 1 && correctWordCount == 1 {
                let distance = levenshteinDistance(normalizedUserAnswer, normalizedCorrectAnswer)
                let threshold = max(2, min(normalizedUserAnswer.count, normalizedCorrectAnswer.count) / 3)
                
                if distance <= threshold {
                    return 0.8 // 80% match for similar single words
                }
            }
        }
        
        // Get word arrays, accommodating for different languages which may not use spaces
        // This works better for languages like English, Spanish, French, etc.
        let userWords = normalizedUserAnswer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let correctWords = normalizedCorrectAnswer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // For character-based languages (Chinese, Japanese, etc.), also compare character by character
        let userChars = Array(normalizedUserAnswer).filter { !$0.isWhitespace }
        let correctChars = Array(normalizedCorrectAnswer).filter { !$0.isWhitespace }
        
        // Calculate word-based similarity (for space-separated languages)
        var wordScore = 0.0
        if !correctWords.isEmpty && !userWords.isEmpty {
            // Find matching words or close variants
            var matchCount = 0
            for userWord in userWords {
                if correctWords.contains(where: { correctWord in
                    if correctWord == userWord { return true }
                    
                    // For longer words, allow partial matches
                    if correctWord.count > 3 && userWord.count > 3 {
                        if correctWord.contains(userWord) || userWord.contains(correctWord) {
                            return true
                        }
                        
                        // Levenshtein with higher tolerance for longer words
                        let distance = levenshteinDistance(correctWord, userWord)
                        let maxLength = max(correctWord.count, userWord.count)
                        if distance <= max(1, Int(Double(maxLength) * 0.3)) {
                            return true
                        }
                    }
                    return false
                }) {
                    matchCount += 1
                }
            }
            
            // Calculate ratio of matching words to total required words
            wordScore = Double(matchCount) / Double(correctWords.count)
        }
        
        // Character-based similarity (helpful for character-based languages)
        var charScore = 0.0
        if !correctChars.isEmpty && !userChars.isEmpty {
            // Simple overlap of characters
            let commonChars = Set(userChars).intersection(Set(correctChars))
            charScore = Double(commonChars.count) / Double(correctChars.count)
        }
        
        // Use the better of the two scores, with a slight bias toward word score
        let finalScore = max(wordScore, charScore * 0.9)
        
        // Apply thresholds for better user experience
        if finalScore > 0.8 { return 1.0 }  // Above 80% match is considered correct
        if finalScore > 0.6 { return 0.8 }  // 60-80% match is good but not perfect
        if finalScore > 0.4 { return 0.5 }  // 40-60% match is partially correct
        if finalScore > 0.2 { return 0.3 }  // 20-40% match has some correct elements
        
        return 0.0  // Below 20% match is considered incorrect
    }
    
    // Helper function to calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aCount = a.count
        let bCount = b.count
        
        if aCount == 0 { return bCount }
        if bCount == 0 { return aCount }
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bCount + 1), count: aCount + 1)
        
        for i in 0...aCount {
            matrix[i][0] = i
        }
        
        for j in 0...bCount {
            matrix[0][j] = j
        }
        
        let aChars = Array(a)
        let bChars = Array(b)
        
        for i in 1...aCount {
            for j in 1...bCount {
                let cost = aChars[i-1] == bChars[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[aCount][bCount]
    }
}
