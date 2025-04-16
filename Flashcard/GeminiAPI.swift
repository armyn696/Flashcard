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
}
