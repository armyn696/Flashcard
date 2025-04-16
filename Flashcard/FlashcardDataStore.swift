import Foundation

class FlashcardDataStore: ObservableObject {
    @Published var projects: [Project] = [] {
        didSet { save() }
    }
    private let saveKey = "flashcard_projects_v1"
    
    init() {
        load()
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
    }
    
    func removeProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
    }
    
    func addFolder(_ folder: Folder, to project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].folders.append(folder)
    }
    
    func removeFolder(_ folder: Folder, from project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        projects[index].folders.removeAll { $0.id == folder.id }
    }
    
    func addFlashcard(_ flashcard: Flashcard, to folder: Folder, in project: Project) {
        guard let projIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let folderIndex = projects[projIndex].folders.firstIndex(where: { $0.id == folder.id }) else { return }
        projects[projIndex].folders[folderIndex].flashcards.append(flashcard)
    }
    
    func removeFlashcard(_ flashcard: Flashcard, from folder: Folder, in project: Project) {
        guard let projIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let folderIndex = projects[projIndex].folders.firstIndex(where: { $0.id == folder.id }) else { return }
        projects[projIndex].folders[folderIndex].flashcards.removeAll { $0.id == flashcard.id }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }
    }
}
