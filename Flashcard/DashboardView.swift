import SwiftUI
import UIKit
import Vision

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
        .listStyle(InsetGroupedListStyle())
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
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage? = nil
    @State private var recognizedText = ""
    
    var body: some View {
        // Two-column grid layout
        let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(folder.flashcards) { card in
                    FlashcardCardView(card: card)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
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
                // Show selected image if any
                if let img = inputImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                // Image picker
                Button("Select Image") { showingImagePicker = true }
                    .sheet(isPresented: $showingImagePicker) {
                        UIKitImagePicker(image: $inputImage)
                    }
                // Recognized text or manual input
                if !recognizedText.isEmpty {
                    TextEditor(text: $recognizedText)
                        .frame(height: 80)
                        .border(Color.gray)
                } else {
                    TextField("Paste your text here", text: $sourceText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: 80)
                }
                if isLoading {
                    ProgressView("Generating...")
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
                Button("Generate") {
                    isLoading = true
                    errorMessage = nil
                    let textToGenerate = recognizedText.isEmpty ? sourceText : recognizedText
                    GeminiAPI.shared.generateFlashcards(from: textToGenerate) { result in
                        isLoading = false
                        switch result {
                        case .success(let cards):
                            for card in cards {
                                dataStore.addFlashcard(card, to: folder, in: project)
                            }
                            sourceText = ""
                            recognizedText = ""
                            showingGenerateFlashcards = false
                        case .failure(let error):
                            errorMessage = error.localizedDescription
                        }
                    }
                }.disabled((sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && recognizedText.isEmpty) || isLoading)
                Button("Cancel") {
                    showingGenerateFlashcards = false
                    sourceText = ""
                    recognizedText = ""
                }
            }
            .padding()
            // OCR on image selection
            .onChange(of: inputImage) { _ in
                if let img = inputImage { performOCR(img) }
            }
        }
    }
    
    /// Perform OCR on selected image
    private func performOCR(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            let texts = request.results?
                .compactMap { $0 as? VNRecognizedTextObservation }
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            DispatchQueue.main.async { recognizedText = texts }
        }
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

struct FlashcardCardView: View {
    let card: Flashcard
    @State private var isFlipped = false
    @State private var userAnswer = ""
    @State private var score: Int? = nil
    @State private var isChecking = false
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                // front view
                VStack {
                    Text(card.question)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
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
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text("Tap to see question")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
            }
            .frame(height: 180)
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isFlipped.toggle()
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            }
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isFlipped)
            
            // Answer input section
            TextField("Your answer", text: $userAnswer)
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)
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
