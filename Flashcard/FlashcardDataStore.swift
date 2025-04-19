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
    
    /// Update an existing flashcard's question and answer
    func updateFlashcard(_ flashcard: Flashcard, in folder: Folder, in project: Project) {
        guard let projIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let folderIndex = projects[projIndex].folders.firstIndex(where: { $0.id == folder.id }) else { return }
        guard let cardIndex = projects[projIndex].folders[folderIndex].flashcards.firstIndex(where: { $0.id == flashcard.id }) else { return }
        projects[projIndex].folders[folderIndex].flashcards[cardIndex] = flashcard
    }
    
    /// Update an existing project (name, icon color, etc.)
    func updateProject(_ project: Project) {
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else { return }
        // Preserve the folders array from the original project
        let folders = projects[index].folders
        
        // Create a new project with updated properties but same folders
        var updatedProject = project
        updatedProject.folders = folders
        
        // Replace the project in the array
        projects[index] = updatedProject
    }
    
    /// Update an existing folder (name, icon color, etc.)
    func updateFolder(_ folder: Folder, in project: Project) {
        guard let projIndex = projects.firstIndex(where: { $0.id == project.id }) else { return }
        guard let folderIndex = projects[projIndex].folders.firstIndex(where: { $0.id == folder.id }) else { return }
        
        // Preserve the flashcards array from the original folder
        let flashcards = projects[projIndex].folders[folderIndex].flashcards
        
        // Create a new folder with updated properties but same flashcards
        var updatedFolder = folder
        updatedFolder.flashcards = flashcards
        
        // Replace the folder in the array
        projects[projIndex].folders[folderIndex] = updatedFolder
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
