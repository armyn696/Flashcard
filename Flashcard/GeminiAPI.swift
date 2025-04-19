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
        let prompt = "Create flashcards from the following text. Respond in JSON format as an array of objects with \"question\" and \"answer\" fields only. Text: \(text)"
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
                DispatchQueue.main.async { completion(.failure(NSError(domain: "No data", code: 0, userInfo: [NSLocalizedDescriptionKey: "The data couldn’t be read because it is missing!"]))) }
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
        let prompt = "Create flashcards from the content of the following image. Respond in JSON format as an array of objects with \"question\" and \"answer\" fields only."
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
    func evaluateAnswer(correct: String, userAnswer: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let urlString = "\(endpoint)\(model):generateContent?key=\(apiKey)"
        print("[GeminiAPI] evaluateAnswer: URL = \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[GeminiAPI] Invalid URL: \(urlString)")
            completion(.failure(NSError(domain: "Invalid URL", code: 0)))
            return
        }
        let prompt = "You are an answer checker for a flashcard app. The user's answer may be in any language. First, translate both the user's answer and the correct answer to English. Then, compare their meanings. If the meanings match, score 100. If they are partially correct, score between 1 and 99. If they are wrong, score 0. Return a JSON object with a single field 'score' whose value is an integer between 0 and 100."
        print("[GeminiAPI] Prompt: \(prompt)")
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(prompt)\nUser's answer: \(userAnswer)\nCorrect answer: \(correct)"]
                    ]
                ]
            ]
        ]
        if let bodyData = try? JSONSerialization.data(withJSONObject: body),
           let bodyString = String(data: bodyData, encoding: .utf8) {
            print("[GeminiAPI] Request body: \(bodyString)")
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
                   let rawText = part["text"] as? String {
                    print("[GeminiAPI] Extracted text: \(rawText)")
                    let jsonString: String
                    if rawText.contains("```json") {
                        jsonString = rawText
                            .replacingOccurrences(of: "```json", with: "")
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if rawText.contains("```") {
                        jsonString = rawText
                            .replacingOccurrences(of: "```", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        jsonString = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    print("[GeminiAPI] JSON to decode: \(jsonString)")
                    if let jsonData = jsonString.data(using: .utf8) {
                        struct ScoreResponse: Decodable { let score: Int }
                        if let resp = try? JSONDecoder().decode(ScoreResponse.self, from: jsonData) {
                            print("[GeminiAPI] Decoded score: \(resp.score)")
                            DispatchQueue.main.async { completion(.success(resp.score)) }
                            return
                        } else {
                            print("[GeminiAPI] Failed to decode score JSON")
                        }
                    }
                    // If JSON decode fails, try extract first integer
                    if let range = rawText.range(of: "\\d+", options: .regularExpression),
                       let value = Int(String(rawText[range])) {
                        print("[GeminiAPI] Extracted score from raw text: \(value)")
                        DispatchQueue.main.async { completion(.success(value)) }
                        return
                    }
                }
                print("[GeminiAPI] Could not parse score from Gemini API response.")
                DispatchQueue.main.async { completion(.failure(NSError(domain: "ParsingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse score from Gemini API response."]))) }
            } catch {
                print("[GeminiAPI] Exception during parsing: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        task.resume()
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
}
