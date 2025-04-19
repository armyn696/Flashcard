import SwiftUI
import UIKit

// Navigation destination identifier enum for type-safe navigation
enum NavigationDestination: Hashable {
    case project(UUID)
    case folder(projectID: UUID, folderID: UUID)
}

struct DashboardView: View {
    @StateObject private var dataStore = FlashcardDataStore()
    @State private var showingAddProject = false
    @State private var newProjectName = ""
    @State private var editingCard: Flashcard? = nil
    @State private var editQuestion = ""
    @State private var editAnswer = ""
    @State private var showingEditSheet = false
    @State private var showingProjectColorPicker = false
    @State private var editingProject: Project? = nil
    @State private var selectedColor: Color = .blue
    
    // Create a navigation path object to manage navigation state
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        // Use NavigationStack instead of NavigationView
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(dataStore.projects) { project in
                    // Instead of a NavigationLink, use a Button
                    Button {
                        // Add project destination to the path
                        navigationPath.append(NavigationDestination.project(project.id))
                    } label: {
                        // Add project icon to label with custom color
                        HStack {
                            Image(systemName: "book.closed.fill")
                                .foregroundColor(project.iconColor)
                            Text(project.name)
                            Spacer()
                            Button {
                                editingProject = project
                                selectedColor = project.iconColor
                                showingProjectColorPicker = true
                            } label: {
                                Image(systemName: "paintpalette")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onDelete(perform: deleteProject)
            }
            .listStyle(InsetGroupedListStyle())
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
                    
                    // Add color picker for new project
                    ColorPicker("Icon Color", selection: $selectedColor)
                        .padding(.horizontal)
                    
                    Button("Add") {
                        let project = Project(name: newProjectName, iconColor: selectedColor)
                        dataStore.addProject(project)
                        newProjectName = ""
                        selectedColor = .blue
                        showingAddProject = false
                    }.disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        showingAddProject = false
                        newProjectName = ""
                        selectedColor = .blue
                    }
                }
                .padding()
            }
            .sheet(isPresented: $showingProjectColorPicker) {
                VStack(spacing: 16) {
                    Text("Change Icon Color").font(.headline)
                    
                    ColorPicker("Select a color", selection: $selectedColor)
                        .padding()
                    
                    HStack {
                        Button("Apply") {
                            if let project = editingProject {
                                // Create an updated project with the new color
                                let updatedProject = Project(
                                    id: project.id,
                                    name: project.name,
                                    folders: project.folders,
                                    iconColor: selectedColor
                                )
                                
                                // Update the project in dataStore
                                dataStore.updateProject(updatedProject)
                            }
                            showingProjectColorPicker = false
                        }
                        
                        Button("Cancel") {
                            showingProjectColorPicker = false
                        }
                    }
                }
                .padding()
            }
            // Define our navigation destinations
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .project(let projectID):
                    if let project = dataStore.projects.first(where: { $0.id == projectID }) {
                        ProjectView(project: project, dataStore: dataStore, navigationPath: $navigationPath)
                    } else {
                        Text("Project not found")
                    }
                case .folder(let projectID, let folderID):
                    if let project = dataStore.projects.first(where: { $0.id == projectID }),
                       let folder = project.folders.first(where: { $0.id == folderID }) {
                        FolderView(project: project, folder: folder, dataStore: dataStore)
                    } else {
                        Text("Folder not found")
                    }
                }
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
    @State private var selectedColor: Color = .yellow
    @State private var showingFolderColorPicker = false
    @State private var editingFolder: Folder? = nil
    
    // Bind to parent's navigation path
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        // Find the up-to-date project state
        guard let currentProject = dataStore.projects.first(where: { $0.id == project.id }) else {
            return AnyView(Text("Project not found").navigationTitle(""))
        }
        
        return AnyView(
            List {
                ForEach(currentProject.folders) { folder in
                    // Instead of NavigationLink, use Button
                    Button {
                        // Add folder destination to the path
                        navigationPath.append(NavigationDestination.folder(projectID: currentProject.id, folderID: folder.id))
                    } label: {
                        // Add folder icon to label with custom color
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(folder.iconColor)
                            Text(folder.name)
                            Spacer()
                            Button {
                                editingFolder = folder
                                selectedColor = folder.iconColor
                                showingFolderColorPicker = true
                            } label: {
                                Image(systemName: "paintpalette")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onDelete(perform: deleteFolder)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(currentProject.name)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
                    
                    // Add color picker for new folder
                    ColorPicker("Icon Color", selection: $selectedColor)
                        .padding(.horizontal)
                    
                    Button("Add") {
                        let newFolder = Folder(name: newFolderName, iconColor: selectedColor)
                        dataStore.addFolder(newFolder, to: project)
                        newFolderName = ""
                        selectedColor = .yellow
                        showingAddFolder = false
                    }.disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        showingAddFolder = false
                        newFolderName = ""
                        selectedColor = .yellow
                    }
                }
                .padding()
            }
            .sheet(isPresented: $showingFolderColorPicker) {
                VStack(spacing: 16) {
                    Text("Change Icon Color").font(.headline)
                    
                    ColorPicker("Select a color", selection: $selectedColor)
                        .padding()
                    
                    HStack {
                        Button("Apply") {
                            if let folder = editingFolder {
                                // Create an updated folder with the new color
                                let updatedFolder = Folder(
                                    id: folder.id,
                                    name: folder.name,
                                    flashcards: folder.flashcards,
                                    iconColor: selectedColor
                                )
                                
                                // Update the folder in dataStore
                                dataStore.updateFolder(updatedFolder, in: project)
                            }
                            showingFolderColorPicker = false
                        }
                        
                        Button("Cancel") {
                            showingFolderColorPicker = false
                        }
                    }
                }
                .padding()
            }
        )
    }
    
    func deleteFolder(at offsets: IndexSet) {
        guard let currentProject = dataStore.projects.first(where: { $0.id == project.id }) else { return }
        
        let foldersToDelete = offsets.map { currentProject.folders[$0] }
        
        for folder in foldersToDelete {
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
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage? = nil
    @State private var editingCard: Flashcard? = nil
    @State private var editQuestion = ""
    @State private var editAnswer = ""
    @State private var showingEditSheet = false
    @State private var isListView = false
    @State private var isExamMode = false
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        guard let currentFolder = dataStore.projects.first(where: { $0.id == project.id })?.folders.first(where: { $0.id == folder.id }) else {
            return AnyView(Text("Folder has been deleted").navigationTitle(""))
        }

        return AnyView(
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { isListView.toggle() }) {
                        Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                            .imageScale(.large)
                    }
                    .padding(.horizontal)
                }
                if isListView {
                    List {
                        ForEach(currentFolder.flashcards, id: \.id) { card in
                            DisclosureGroup {
                                Text(card.answer)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } label: {
                                Text(card.question)
                                    .font(.headline)
                            }
                            .padding(.vertical, 8)
                        }
                        .onDelete { offsets in
                            deleteFlashcard(at: offsets, from: folder, in: project)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                            ForEach(currentFolder.flashcards, id: \.id) { card in
                                FlashcardCardView(
                                    card: card,
                                    onEdit: {
                                        editingCard = card
                                        editQuestion = card.question
                                        editAnswer = card.answer
                                        showingEditSheet = true
                                    },
                                    onDelete: {
                                        DispatchQueue.main.async {
                                            dataStore.removeFlashcard(card, from: folder, in: project)
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { hideKeyboard() }
                }
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
                    Button(action: { isExamMode = true }) {
                        Image(systemName: "play.circle")
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
                    }.disabled(newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    HStack(spacing: 16) {
                        Button("Select Image") { showingImagePicker = true }
                        if inputImage != nil {
                            Button("Clear Image") { inputImage = nil }
                        }
                    }
                    if let img = inputImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                    }
                    TextField("Enter text or URL to generate flashcards", text: $sourceText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    HStack {
                        Button("Generate") {
                            isLoading = true
                            errorMessage = nil
                            if let img = inputImage {
                                GeminiAPI.shared.generateFlashcards(from: img) { result in
                                    DispatchQueue.main.async {
                                        isLoading = false
                                        switch result {
                                        case .success(let cards):
                                            cards.forEach { dataStore.addFlashcard($0, to: folder, in: project) }
                                            showingGenerateFlashcards = false
                                            sourceText = ""
                                            inputImage = nil
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            } else {
                                GeminiAPI.shared.generateFlashcards(from: sourceText) { result in
                                    DispatchQueue.main.async {
                                        isLoading = false
                                        switch result {
                                        case .success(let cards):
                                            cards.forEach { dataStore.addFlashcard($0, to: folder, in: project) }
                                            showingGenerateFlashcards = false
                                            sourceText = ""
                                        case .failure(let error):
                                            errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        }
                        .disabled((inputImage == nil && sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || isLoading)
                        Button("Cancel") {
                            showingGenerateFlashcards = false
                            sourceText = ""
                        }
                    }
                    if isLoading { ProgressView().padding(.top) }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .background(
                EmptyView()
                    .sheet(isPresented: $showingImagePicker) {
                        UIKitImagePicker(image: $inputImage)
                    }
            )
            .fullScreenCover(isPresented: $isExamMode) {
                ExamView(flashcards: currentFolder.flashcards)
            }
            .sheet(isPresented: $showingEditSheet) {
                VStack(spacing: 16) {
                    Text("Edit Flashcard").font(.headline)
                    TextField("Question", text: $editQuestion)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Answer", text: $editAnswer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    HStack(spacing: 16) {
                        Button("Save") {
                            if let original = editingCard {
                                let updated = Flashcard(id: original.id, question: editQuestion, answer: editAnswer)
                                dataStore.updateFlashcard(updated, in: folder, in: project)
                            }
                            showingEditSheet = false
                            editingCard = nil
                        }
                        .disabled(editQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Cancel") {
                            showingEditSheet = false
                            editingCard = nil
                        }
                    }
                }
                .padding()
            }
        )
    }
    
    func deleteFlashcard(at offsets: IndexSet, from folder: Folder, in project: Project) {
        guard let currentFolderState = dataStore.projects.first(where: { $0.id == project.id })?.folders.first(where: { $0.id == folder.id }) else {
            print("Error: Could not find current folder state for deletion")
            return
        }
        let cardsToDelete = offsets.map { currentFolderState.flashcards[$0] }
        
        DispatchQueue.main.async {
            for card in cardsToDelete {
                dataStore.removeFlashcard(card, from: folder, in: project)
            }
        }
    }
}

struct FlashcardCardView: View {
    let card: Flashcard
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isFlipped = false
    @State private var userAnswer = ""
    @State private var score: Int? = nil
    @State private var isChecking = false
    @State private var showFullscreen = false
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark ? UIColor(red: 30/255, green: 30/255, blue: 32/255, alpha: 1) : UIColor.white
                    }))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor { trait in
                                trait.userInterfaceStyle == .dark ? UIColor(white: 0.4, alpha: 1) : UIColor.black
                            }), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 5, x: 0, y: 2)
                // front view
                VStack {
                    Text(card.question)
                        .font(card.question.count > 80 ? .caption : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text("Tap to see answer")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .opacity(isFlipped ? 0 : 1)
                // back view
                VStack {
                    Text(card.answer)
                        .font(card.answer.count > 80 ? .caption : .title2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Text("Tap to see question")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
            }
            .frame(minHeight: 180)
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isFlipped.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                showFullscreen = true
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isFlipped)
            .sheet(isPresented: $showFullscreen) {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? UIColor(red: 30/255, green: 30/255, blue: 32/255, alpha: 1) : UIColor.white
                                }))
                                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
                            VStack {
                                Text(isFlipped ? card.answer : card.question)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                Text(isFlipped ? "Tap to see question" : "Tap to see answer")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isFlipped.toggle()
                            }
                        }
                        Button(action: { showFullscreen = false }) {
                            Text("Close")
                                .font(.title2)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .padding(.top, 24)
                    }
                }
            }
            // Answer input section
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                TextField("Your answer", text: $userAnswer)
                    .padding(8)
                    .background(Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1) : UIColor.white
                    }))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .foregroundColor(Color.primary)
                    .padding(.horizontal)
            }
            HStack {
                Button("Check") {
                    isChecking = true
                    score = nil
                    GeminiAPI.shared.evaluateAnswer(correct: card.answer, userAnswer: userAnswer) { result in
                        isChecking = false
                        if case .success(let value) = result {
                            score = value
                        }
                    }
                }
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
                if isChecking {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else if let score = score {
                    Text("Score: \(score)%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            HStack(spacing: 8) {
                Button(action: onEdit) { Image(systemName: "pencil") }
                Button(action: onDelete) { Image(systemName: "trash") }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.caption2)
        } // VStack
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}

/// UIKit UIImagePickerController bridge for SwiftUI
struct UIKitImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: UIKitImagePicker
        init(_ parent: UIKitImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Full-screen exam mode view
struct ExamView: View {
    let flashcards: [Flashcard]
    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var cardOffset: CGSize = .zero
    @Environment(\.presentationMode) var presentationMode
    @State private var userAnswer = ""
    @State private var score: Int? = nil
    @State private var isChecking = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                Color(UIColor.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                VStack {
                    Spacer()
                    if currentIndex < flashcards.count {
                        ProgressView(value: Double(currentIndex + 1), total: Double(flashcards.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: Color.accentColor))
                            .padding(.horizontal)
                        Text("Card \(currentIndex + 1) of \(flashcards.count)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        HStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(UIColor { trait in
                                        trait.userInterfaceStyle == .dark ? UIColor(red: 30/255, green: 30/255, blue: 32/255, alpha: 1) : UIColor.white
                                    }))
                                    .shadow(radius: 5)
                                    .rotation3DEffect(.degrees(showAnswer ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text(showAnswer ? "Answer" : "Question")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.accentColor)
                                            .padding(8)
                                            .background(Color.accentColor.opacity(0.12))
                                            .cornerRadius(8)
                                            .padding([.top, .trailing], 10)
                                    }
                                    Spacer()
                                }
                                Text(showAnswer ? flashcards[currentIndex].answer : flashcards[currentIndex].question)
                                    .font(.largeTitle)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .foregroundColor(.primary)
                            }
                            .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.7)
                            .offset(x: cardOffset.width)
                            .rotationEffect(.degrees(Double(cardOffset.width / 10)))
                            .gesture(
                                DragGesture()
                                    .onChanged { cardOffset = $0.translation }
                                    .onEnded { gesture in
                                        let threshold: CGFloat = 100
                                        if gesture.translation.width > threshold, currentIndex > 0 { currentIndex -= 1 }
                                        else if gesture.translation.width < -threshold, currentIndex < flashcards.count - 1 { currentIndex += 1 }
                                        showAnswer = false
                                        cardOffset = .zero
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showAnswer.toggle()
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showAnswer)
                            Spacer()
                        }
                    } else {
                        VStack {
                            Spacer()
                            Text("Exam Complete!")
                                .font(.largeTitle)
                                .padding()
                            Button("Done") { presentationMode.wrappedValue.dismiss() }
                                .font(.title2)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            Spacer()
                        }
                    }
                    if currentIndex < flashcards.count {
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                            TextField("Your answer", text: $userAnswer)
                                .padding(8)
                                .background(Color(UIColor { trait in
                                    trait.userInterfaceStyle == .dark ? UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1) : UIColor.white
                                }))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                .foregroundColor(Color.primary)
                                .padding(.horizontal)
                        }
                        HStack {
                            Button("Check") {
                                isChecking = true
                                score = nil
                                GeminiAPI.shared.evaluateAnswer(correct: flashcards[currentIndex].answer, userAnswer: userAnswer) { result in
                                    isChecking = false
                                    if case .success(let value) = result {
                                        score = value
                                    }
                                }
                            }
                            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
                            if isChecking {
                                ProgressView()
                                    .frame(width: 20, height: 20)
                            } else if let score = score {
                                Text("Score: \(score)%")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 8)
                    } else {
                        VStack {
                            Spacer()
                            Text("Exam Complete!")
                                .font(.largeTitle)
                                .padding()
                            Button("Done") { presentationMode.wrappedValue.dismiss() }
                                .font(.title2)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .onChange(of: currentIndex) { _ in
                    userAnswer = ""
                    score = nil
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}
