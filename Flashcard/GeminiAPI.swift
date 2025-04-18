import Foundation

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
    
    /// Evaluate user's answer correctness and return a percentage score via API
    func evaluateAnswer(correct: String, userAnswer: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let urlString = "\(endpoint)\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            // fallback to local scoring on invalid URL
            let local = simpleLocalScore(correct: correct, userAnswer: userAnswer)
            completion(.success(local))
            return
        }
        let prompt = "Evaluate the following student's answer: \"\(userAnswer)\" against the correct answer: \"\(correct)\". Return a JSON object with a single field \"score\" whose value is an integer between 0 and 100."
        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [ ["text": prompt] ]
                ]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                // network error: fallback
                let local = self.simpleLocalScore(correct: correct, userAnswer: userAnswer)
                DispatchQueue.main.async { completion(.success(local)) }
                return
            }
            guard let data = data else {
                // no data: fallback
                let local = self.simpleLocalScore(correct: correct, userAnswer: userAnswer)
                DispatchQueue.main.async { completion(.success(local)) }
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let part = parts.first,
                   let rawText = part["text"] as? String {
                    // Extract JSON if present
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
                    // Attempt JSON decode
                    if let jsonData = jsonString.data(using: .utf8) {
                        struct ScoreResponse: Decodable { let score: Int }
                        if let resp = try? JSONDecoder().decode(ScoreResponse.self, from: jsonData) {
                            DispatchQueue.main.async { completion(.success(resp.score)) }
                            return
                        }
                    }
                    // If JSON decode fails, try extract first integer
                    if let range = rawText.range(of: "\\d+", options: .regularExpression),
                       let value = Int(String(rawText[range])) {
                        DispatchQueue.main.async { completion(.success(value)) }
                        return
                    }
                }
                // If parsing chain fails, fallback
                let local = self.simpleLocalScore(correct: correct, userAnswer: userAnswer)
                DispatchQueue.main.async { completion(.success(local)) }
            } catch {
                // parsing error: fallback
                let local = self.simpleLocalScore(correct: correct, userAnswer: userAnswer)
                DispatchQueue.main.async { completion(.success(local)) }
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
