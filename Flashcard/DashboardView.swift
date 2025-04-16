import SwiftUI

struct DashboardView: View {
    @StateObject private var dataStore = FlashcardDataStore()
    @State private var showingAddProject = false
    @State private var newProjectName = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(dataStore.projects) { project in
                    NavigationLink(destination: ProjectView(project: project, dataStore: dataStore)) {
                        Text(project.name)
                    }
                }
                .onDelete(perform: deleteProject)
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddProject = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                VStack(spacing: 16) {
                    Text("New Project").font(.headline)
                    TextField("Project name", text: $newProjectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    Button("Add") {
                        let project = Project(name: newProjectName)
                        dataStore.addProject(project)
                        newProjectName = ""
                        showingAddProject = false
                    }.disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        showingAddProject = false
                        newProjectName = ""
                    }
                }
                .padding()
            }
        }
    }
    
    func deleteProject(at offsets: IndexSet) {
        for index in offsets {
            let project = dataStore.projects[index]
            dataStore.removeProject(project)
        }
    }
}

struct ProjectView: View {
    let project: Project
    @ObservedObject var dataStore: FlashcardDataStore
    @State private var showingAddFolder = false
    @State private var newFolderName = ""
    
    var body: some View {
        List {
            ForEach(project.folders) { folder in
                NavigationLink(destination: FolderView(project: project, folder: folder, dataStore: dataStore)) {
                    Text(folder.name)
                }
            }
            .onDelete(perform: deleteFolder)
        }
        .navigationTitle(project.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFolder = true }) {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddFolder) {
            VStack(spacing: 16) {
                Text("New Folder").font(.headline)
                TextField("Folder name", text: $newFolderName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                Button("Add") {
                    let folder = Folder(name: newFolderName)
                    dataStore.addFolder(folder, to: project)
                    newFolderName = ""
                    showingAddFolder = false
                }.disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") {
                    showingAddFolder = false
                    newFolderName = ""
                }
            }
            .padding()
        }
    }
    
    func deleteFolder(at offsets: IndexSet) {
        for index in offsets {
            let folder = project.folders[index]
            dataStore.removeFolder(folder, from: project)
        }
    }
}

struct FolderView: View {
    let project: Project
    let folder: Folder
    @ObservedObject var dataStore: FlashcardDataStore
    @State private var showingAddFlashcard = false
    @State private var showingGenerateFlashcards = false
    @State private var newQuestion = ""
    @State private var newAnswer = ""
    @State private var sourceText = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(folder.flashcards) { card in
                    FlashcardCardView(card: card)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle(folder.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showingAddFlashcard = true }) {
                    Image(systemName: "plus.square.on.square")
                }
                Button(action: { showingGenerateFlashcards = true }) {
                    Image(systemName: "sparkles")
                }
            }
        }
        .sheet(isPresented: $showingAddFlashcard) {
            VStack(spacing: 16) {
                Text("New Flashcard").font(.headline)
                TextField("Question", text: $newQuestion)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Answer", text: $newAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") {
                    let card = Flashcard(question: newQuestion, answer: newAnswer)
                    dataStore.addFlashcard(card, to: folder, in: project)
                    newQuestion = ""
                    newAnswer = ""
                    showingAddFlashcard = false
                }.disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty || newAnswer.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Cancel") {
                    showingAddFlashcard = false
                    newQuestion = ""
                    newAnswer = ""
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingGenerateFlashcards) {
            VStack(spacing: 16) {
                Text("Generate Flashcards with Gemini").font(.headline)
                TextField("Paste your text here", text: $sourceText, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 80)
                if isLoading {
                    ProgressView("Generating...")
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                Button("Generate") {
                    isLoading = true
                    errorMessage = nil
                    GeminiAPI.shared.generateFlashcards(from: sourceText) { result in
                        isLoading = false
                        switch result {
                        case .success(let cards):
                            for card in cards {
                                dataStore.addFlashcard(card, to: folder, in: project)
                            }
                            sourceText = ""
                            showingGenerateFlashcards = false
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }.disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                Button("Cancel") {
                    showingGenerateFlashcards = false
                    sourceText = ""
                }
            }
            .padding()
        }
    }
    
    func deleteFlashcard(at offsets: IndexSet) {
        for index in offsets {
            let card = folder.flashcards[index]
            dataStore.removeFlashcard(card, from: folder, in: project)
        }
    }
}

struct FlashcardCardView: View {
    let card: Flashcard
    @State private var isFlipped = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(isFlipped ? Color.blue.opacity(0.1) : Color.yellow.opacity(0.2))
                .shadow(radius: 4)
            Group {
                if isFlipped {
                    VStack {
                        Text(card.answer)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                        Text("Tap to see question")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    VStack {
                        Text(card.question)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                        Text("Tap to see answer")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 180)
        .onTapGesture {
            withAnimation(.spring()) { isFlipped.toggle() }
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.spring(), value: isFlipped)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
