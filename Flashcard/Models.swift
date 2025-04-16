import Foundation

struct Flashcard: Codable, Identifiable, Equatable {
    var id: UUID
    var question: String
    var answer: String
    
    init(id: UUID = UUID(), question: String, answer: String) {
        self.id = id
        self.question = question
        self.answer = answer
    }
}

struct Folder: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var flashcards: [Flashcard]
    
    init(id: UUID = UUID(), name: String, flashcards: [Flashcard] = []) {
        self.id = id
        self.name = name
        self.flashcards = flashcards
    }
}

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var folders: [Folder]
    
    init(id: UUID = UUID(), name: String, folders: [Folder] = []) {
        self.id = id
        self.name = name
        self.folders = folders
    }
}
