import Foundation
import SwiftUI

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

// Helper to make Color Codable
extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Double.self, forKey: .red)
        let g = try container.decode(Double.self, forKey: .green)
        let b = try container.decode(Double.self, forKey: .blue)
        let a = try container.decode(Double.self, forKey: .alpha)
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        #if os(iOS)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        NSColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        
        try container.encode(r, forKey: .red)
        try container.encode(g, forKey: .green)
        try container.encode(b, forKey: .blue)
        try container.encode(a, forKey: .alpha)
    }
}

struct Folder: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var flashcards: [Flashcard]
    var iconColor: Color
    
    init(id: UUID = UUID(), name: String, flashcards: [Flashcard] = [], iconColor: Color = .yellow) {
        self.id = id
        self.name = name
        self.flashcards = flashcards
        self.iconColor = iconColor
    }
}

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var folders: [Folder]
    var iconColor: Color
    
    init(id: UUID = UUID(), name: String, folders: [Folder] = [], iconColor: Color = .blue) {
        self.id = id
        self.name = name
        self.folders = folders
        self.iconColor = iconColor
    }
}
