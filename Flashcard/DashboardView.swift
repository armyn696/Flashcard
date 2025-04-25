import SwiftUI
import UIKit
import PDFKit

// Define app colors as constants for consistency
let textColor = Color(hex: "#E1E1E1")
let backgroundColor = Color(hex: "#000000")
let cardColor = Color(hex: "#1c1c1e")

// Add extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Loading screen view that shows on app startup
struct LoadingView: View {
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            VStack {
                if let uiImage = UIImage(named: "loading.PNG") ?? UIImage(named: "AppIcon.appiconset/loading.PNG") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                } else {
                    // Fallback if image can't be found
                    VStack(spacing: 20) {
                        Text("Loading...")
                            .font(.title)
                            .foregroundColor(textColor)
                        
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                }
            }
        }
    }
}

// Navigation destination identifier enum for type-safe navigation
enum NavigationDestination: Hashable {
    case project(UUID)
    case folder(projectID: UUID, folderID: UUID)
    case pdfViewer(projectID: UUID, folderID: UUID, pdfURL: URL)
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
    @State private var isLoading = true
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    // Create a navigation path object to manage navigation state
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        // Use NavigationStack instead of NavigationView
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Dark background
                backgroundColor.edgesIgnoringSafeArea(.all)
                
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
                                    .foregroundColor(textColor)
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
                        .listRowBackground(cardColor)
                    }
                    .onDelete(perform: deleteProject)
                }
                .scrollContentBackground(.hidden)
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Projects")
                .toolbarColorScheme(.dark)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddProject = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Loading screen overlay only on first launch
                if isLoading && !hasLaunchedBefore {
                    LoadingView()
                        .transition(.opacity)
                        .zIndex(100) // Ensure it's on top
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddProject = true }) {
                            ZStack {
                                // Outer glow effect
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 5)
                                
                                // Button background
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .shadow(radius: 4)
                                
                                // Thicker plus symbol
                                Image(systemName: "plus")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .onAppear {
                // Only show loading screen on first app launch
                if !hasLaunchedBefore {
                    // Set the flag to true so we don't show loading again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            isLoading = false
                            hasLaunchedBefore = true
                        }
                    }
                } else {
                    // Skip loading if not first launch
                    isLoading = false
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
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
            }
            // Define our navigation destinations
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .project(let projectID):
                    if let project = dataStore.projects.first(where: { $0.id == projectID }) {
                        ProjectView(project: project, dataStore: dataStore, navigationPath: $navigationPath)
                    } else {
                        Text("Project not found")
                            .foregroundColor(.white)
                    }
                case .folder(let projectID, let folderID):
                    if let project = dataStore.projects.first(where: { $0.id == projectID }),
                       let folder = project.folders.first(where: { $0.id == folderID }) {
                        FolderView(project: project, folder: folder, dataStore: dataStore, navigationPath: $navigationPath)
                    } else {
                        Text("Folder not found")
                            .foregroundColor(.white)
                    }
                case .pdfViewer(let projectID, let folderID, let pdfURL):
                    PDFViewer(pdfURL: pdfURL)
                }
            }
        }
        .preferredColorScheme(.dark)
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
    @State private var showingDocumentPicker = false
    @State private var newFolderName = ""
    @State private var selectedColor: Color = .yellow
    @State private var showingFolderColorPicker = false
    @State private var editingFolder: Folder? = nil
    @State private var showingMenu = false // For the popup menu
    
    // Bind to parent's navigation path
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        // Find the up-to-date project state
        guard let currentProject = dataStore.projects.first(where: { $0.id == project.id }) else {
            return AnyView(Text("Project not found").navigationTitle("").foregroundColor(textColor))
        }
        
        return AnyView(
            ZStack {
                // Dark background
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                List {
                    ForEach(currentProject.folders) { folder in
                        // Instead of NavigationLink, use Button
                        Button {
                            // Check if it's a PDF folder
                            if folder.name.hasPrefix("PDF:") {
                                // Get the PDF URL from UserDefaults
                                let defaults = UserDefaults.standard
                                if let pdfPath = defaults.string(forKey: "pdf_\(folder.id.uuidString)") {
                                    // Create a proper file URL
                                    let pdfURL = URL(fileURLWithPath: pdfPath)
                                    
                                    // Check if file exists
                                    if FileManager.default.fileExists(atPath: pdfPath) {
                                        // Navigate to PDF viewer
                                        navigationPath.append(NavigationDestination.pdfViewer(projectID: currentProject.id, folderID: folder.id, pdfURL: pdfURL))
                                    } else {
                                        // PDF file doesn't exist anymore, show folder view instead
                                        print("PDF file not found at path: \(pdfPath)")
                                        navigationPath.append(NavigationDestination.folder(projectID: currentProject.id, folderID: folder.id))
                                    }
                                } else {
                                    // Fallback to regular folder view if PDF not found in UserDefaults
                                    navigationPath.append(NavigationDestination.folder(projectID: currentProject.id, folderID: folder.id))
                                }
                            } else {
                                // Regular folder
                                navigationPath.append(NavigationDestination.folder(projectID: currentProject.id, folderID: folder.id))
                            }
                        } label: {
                            // Add folder icon to label with custom color
                            HStack {
                                // Check if it's a PDF folder and use appropriate icon
                                Image(systemName: folder.name.hasPrefix("PDF:") ? "doc.text.fill" : "folder.fill")
                                    .foregroundColor(folder.iconColor)
                                Text(folder.name)
                                    .foregroundColor(textColor)
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
                        .listRowBackground(cardColor)
                    }
                    .onDelete(perform: deleteFolder)
                }
                .scrollContentBackground(.hidden)
                .listStyle(InsetGroupedListStyle())
                .navigationTitle(currentProject.name)
                .toolbarColorScheme(.dark)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: { showingAddFolder = true }) {
                            Image(systemName: "folder.badge.plus")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Floating Action Button and Menu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // Menu popup when button is pressed
                        if showingMenu {
                            VStack(spacing: 15) {
                                // Add Folder option
                                Button(action: {
                                    showingMenu = false
                                    showingAddFolder = true
                                }) {
                                    HStack {
                                        Image(systemName: "folder.badge.plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Add Folder")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(cardColor)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.2), radius: 5)
                                }
                                
                                // Add PDF option
                                Button(action: {
                                    showingMenu = false
                                    showingDocumentPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.badge.plus")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Add PDF")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .background(cardColor)
                                    .cornerRadius(20)
                                    .shadow(color: Color.black.opacity(0.2), radius: 5)
                                }
                            }
                            .padding(.bottom, 85)
                            .padding(.trailing, 20)
                            .transition(.scale)
                        }
                        
                        // Floating Action Button
                        Button(action: { 
                            withAnimation(.spring()) {
                                showingMenu.toggle()
                            }
                        }) {
                            ZStack {
                                // Outer glow effect
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 5)
                                
                                // Button background
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .shadow(radius: 4)
                                
                                // Thicker plus symbol
                                Image(systemName: "plus")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(.black)
                                    .rotationEffect(showingMenu ? .degrees(45) : .degrees(0))
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
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
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingDocumentPicker) {
                PDFDocumentPicker(project: project, dataStore: dataStore)
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

/// UIKit UIDocumentPickerViewController bridge for SwiftUI to select PDFs
struct PDFDocumentPicker: UIViewControllerRepresentable {
    let project: Project
    @ObservedObject var dataStore: FlashcardDataStore
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: PDFDocumentPicker
        
        init(_ parent: PDFDocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Create a folder with the PDF name
            let pdfName = url.deletingPathExtension().lastPathComponent
            let newFolder = Folder(name: "PDF: \(pdfName)", iconColor: .red)
            
            // Start file access
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access the PDF file")
                return
            }
            
            // Create a local copy of the file in the app's document directory
            do {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
                
                // Remove any existing file
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Add the folder to the project
                DispatchQueue.main.async {
                    self.parent.dataStore.addFolder(newFolder, to: self.parent.project)
                    
                    // Store the PDF URL for this folder ID in UserDefaults - store as string path
                    let defaults = UserDefaults.standard
                    defaults.set(destinationURL.path, forKey: "pdf_\(newFolder.id.uuidString)")
                    
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                print("Error copying PDF file: \(error)")
            }
            
            // Stop file access
            url.stopAccessingSecurityScopedResource()
        }
    }
}

// Add FileManager extension to check if file exists
extension FileManager {
    func fileExists(at path: String) -> Bool {
        fileExists(atPath: path)
    }
}

struct FolderView: View {
    let project: Project
    let folder: Folder
    @ObservedObject var dataStore: FlashcardDataStore
    @Binding var navigationPath: NavigationPath
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
    @State private var shuffledCards: [Flashcard]? = nil
    @State private var dragOffset: CGFloat = 0
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func shuffleCards() {
        guard let currentFolder = dataStore.projects.first(where: { $0.id == project.id })?.folders.first(where: { $0.id == folder.id }) else { return }
        
        // Always create a new shuffle
        var cards = shuffledCards ?? currentFolder.flashcards
        cards.shuffle()
        shuffledCards = cards
    }
    
    var body: some View {
        guard let currentFolder = dataStore.projects.first(where: { $0.id == project.id })?.folders.first(where: { $0.id == folder.id }) else {
            return AnyView(Text("Folder has been deleted").navigationTitle("").foregroundColor(textColor))
        }

        // Use either shuffled cards or original cards
        let displayedCards = shuffledCards ?? currentFolder.flashcards

        return AnyView(
            ZStack {
                // Dark background
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button(action: shuffleCards) {
                            Image(systemName: "shuffle")
                                .imageScale(.large)
                                .foregroundColor(textColor)
                        }
                        .padding(.horizontal, 4)
                        Button(action: { isListView.toggle() }) {
                            Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                                .imageScale(.large)
                                .foregroundColor(textColor)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    if isListView {
                        List {
                            ForEach(displayedCards, id: \.id) { card in
                                DisclosureGroup {
                                    Text(card.answer)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 4)
                                } label: {
                                    Text(card.question)
                                        .font(.headline)
                                        .foregroundColor(textColor)
                                }
                                .padding(.vertical, 8)
                                .listRowBackground(cardColor)
                            }
                            .onDelete { offsets in
                                deleteFlashcard(at: offsets, from: folder, in: project)
                                // Reset shuffled state if cards are deleted
                                shuffledCards = nil
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .listStyle(InsetGroupedListStyle())
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                                ForEach(displayedCards, id: \.id) { card in
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
                                                // Reset shuffled state if cards are deleted
                                                shuffledCards = nil
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
                .toolbarColorScheme(.dark)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: { showingAddFlashcard = true }) {
                            Image(systemName: "plus.square.on.square")
                                .foregroundColor(.white)
                        }
                        Button(action: { showingGenerateFlashcards = true }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.white)
                        }
                        Button(action: { isExamMode = true }) {
                            Image(systemName: "play.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddFlashcard = true }) {
                            ZStack {
                                // Outer glow effect
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                    .blur(radius: 5)
                                
                                // Button background
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                                    .shadow(radius: 4)
                                
                                // Thicker plus symbol
                                Image(systemName: "plus")
                                    .font(.system(size: 25, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            // Add a swipe right gesture to navigate back
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width > 0 {
                            // Only track right swipes (positive width)
                            self.dragOffset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.width > 100 {
                            // Pop back to the project view if swiped right enough
                            if navigationPath.count > 0 {
                                // Add haptic feedback
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation {
                                    navigationPath.removeLast()
                                }
                            }
                        }
                        // Reset offset
                        self.dragOffset = 0
                    }
            )
            .offset(x: dragOffset / 4) // Add some visual feedback, but don't move the view too much
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
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
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
                .preferredColorScheme(.dark)
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
    
    // Fixed card dimensions
    private let cardWidth: CGFloat = 160
    private let cardHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(UIColor.gray), lineWidth: 1)
                    )
                    .shadow(color: backgroundColor.opacity(0.18), radius: 5, x: 0, y: 2)
                // front view
                VStack {
                    Spacer(minLength: 10)
                    Text(card.question)
                        .font(card.question.count > 80 ? .caption : (card.question.count > 40 ? .body : .title3))
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text("Tap to see answer")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                }
                .padding(8)
                .opacity(isFlipped ? 0 : 1)
                // back view
                VStack {
                    Spacer(minLength: 10)
                    Text(card.answer)
                        .font(card.answer.count > 80 ? .caption : (card.answer.count > 40 ? .body : .title3))
                        .fontWeight(.medium)
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .minimumScaleFactor(0.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Text("Tap to see question")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 5)
                }
                .padding(8)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
            }
            .frame(width: cardWidth, height: cardHeight)
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
                    backgroundColor.edgesIgnoringSafeArea(.all)
                    VStack(spacing: 24) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 32)
                                .fill(cardColor)
                                .shadow(color: backgroundColor.opacity(0.3), radius: 12, x: 0, y: 6)
                            VStack {
                                Text(isFlipped ? card.answer : card.question)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(textColor)
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
                                .background(Color.blue)
                                .foregroundColor(textColor)
                                .cornerRadius(16)
                        }
                        .padding(.top, 24)
                    }
                }
                .preferredColorScheme(.dark)
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
                    .background(cardColor)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .foregroundColor(textColor)
                    .padding(.horizontal)
            }
            HStack {
                Button("Check") {
                    isChecking = true
                    score = nil
                    Task {
                        let result = await GeminiAPI.shared.evaluateAnswer(userAnswer: userAnswer, correctAnswer: card.answer)
                        isChecking = false
                        score = Int(result * 100)
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
                Button(action: onEdit) { 
                    Image(systemName: "pencil")
                        .foregroundColor(textColor)
                }
                Button(action: onDelete) { 
                    Image(systemName: "trash")
                        .foregroundColor(textColor) 
                }
                Spacer()
            }
            .buttonStyle(.plain)
            .font(.caption2)
        } // VStack
        .frame(width: cardWidth)
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
                // Use pure black background
                backgroundColor
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                VStack {
                    Spacer()
                    if currentIndex < flashcards.count {
                        ProgressView(value: Double(currentIndex + 1), total: Double(flashcards.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: Color.blue))
                            .padding(.horizontal)
                        Text("Card \(currentIndex + 1) of \(flashcards.count)")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                        HStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(cardColor)
                                    .shadow(radius: 5)
                                    .rotation3DEffect(.degrees(showAnswer ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                                VStack {
                                    HStack {
                                        Spacer()
                                        Text(showAnswer ? "Answer" : "Question")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                            .padding(8)
                                            .background(Color.blue.opacity(0.12))
                                            .cornerRadius(8)
                                            .padding([.top, .trailing], 10)
                                    }
                                    Spacer()
                                }
                                Text(showAnswer ? flashcards[currentIndex].answer : flashcards[currentIndex].question)
                                    .font(.largeTitle)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .foregroundColor(textColor)
                                    .minimumScaleFactor(0.4)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                .foregroundColor(textColor)
                                .padding()
                            Button("Done") { presentationMode.wrappedValue.dismiss() }
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(textColor)
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
                                .background(cardColor)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                                .foregroundColor(textColor)
                                .padding(.horizontal)
                        }
                        HStack {
                            Button("Check") {
                                isChecking = true
                                score = nil
                                Task {
                                    let result = await GeminiAPI.shared.evaluateAnswer(userAnswer: userAnswer, correctAnswer: flashcards[currentIndex].answer)
                                    isChecking = false
                                    score = Int(result * 100)
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
                    }
                    Spacer()
                }
                .onChange(of: currentIndex) { _ in
                    userAnswer = ""
                    score = nil
                }
            }
            .preferredColorScheme(.dark)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }
}

// Create a simple PDF viewer with top and bottom bars like the screenshot
struct PDFViewer: View {
    let pdfURL: URL
    @Environment(\.presentationMode) var presentationMode
    @State private var showHighlightMode = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top navigation bar - simplified like the screenshot
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(.leading)
                    }
                    
                    Spacer()
                    
                    Text("PDF Viewer")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        // More options
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(.trailing)
                    }
                }
                .padding(.top, 44)
                .padding(.bottom, 8)
                .background(Color.black)
                
                // Toolbar with icons
                HStack(spacing: 0) {
                    // Highlight button
                    ToolbarButton(icon: "pencil", label: "Highlight", isSelected: showHighlightMode) {
                        showHighlightMode.toggle()
                    }
                    
                    // Undo button
                    ToolbarButton(icon: "arrow.uturn.backward", label: "Undo", isSelected: false) {
                        NotificationCenter.default.post(name: NSNotification.Name("UndoLastHighlight"), object: nil)
                    }
                    
                    // Underline button
                    ToolbarButton(icon: "underline", label: "Underline", isSelected: false) {
                        // Underline action
                    }
                    
                    // Note button
                    ToolbarButton(icon: "text.bubble", label: "Note", isSelected: false) {
                        // Note action
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.black)
                
                // PDF Content - Full screen
                StrictZoomPDFView(pdfURL: pdfURL, showHighlightMode: showHighlightMode)
                    .edgesIgnoringSafeArea(.horizontal)
                
                // Bottom toolbar
                HStack(spacing: 0) {
                    BottomToolbarButton(icon: "square.grid.2x2", label: "Pages") {
                        // Pages action
                    }
                    
                    BottomToolbarButton(icon: "magnifyingglass", label: "Search") {
                        // Search action
                    }
                    
                    BottomToolbarButton(icon: "bookmark", label: "Bookmarks") {
                        // Bookmarks action
                    }
                    
                    BottomToolbarButton(icon: "doc.text", label: "Outline") {
                        // Outline action
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 30) // Extra padding for home indicator
                .background(Color.black)
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .edgesIgnoringSafeArea(.all)
        .preferredColorScheme(.dark)
    }
}

// Top toolbar button with icon and label
struct ToolbarButton: View {
    var icon: String
    var label: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .yellow : .white)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .yellow : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? Color.yellow.opacity(0.15) : Color.clear)
            .cornerRadius(8)
        }
    }
}

// Bottom toolbar button
struct BottomToolbarButton: View {
    var icon: String
    var label: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }
}

// Create extension to access PDFView's scrollView for better control
extension PDFView {
    var pdfScrollView: UIScrollView? {
        // Find the scroll view within PDFView's subviews
        return subviews.first { $0 is UIScrollView } as? UIScrollView
    }
}

// Modify StrictZoomPDFView to remove DrawingView and update gesture handling
struct StrictZoomPDFView: UIViewRepresentable {
    let pdfURL: URL
    var showHighlightMode: Bool
    
    func makeUIView(context: Context) -> UIView {
        // Create the PDF view (Container view no longer needed)
        let pdfView = PDFView()
        pdfView.tag = 100 // Keep tag for reference if needed
        pdfView.backgroundColor = .black
        
        // Configure PDF view
        setupPDFView(pdfView, context: context)
        
        return pdfView // Return PDFView directly
    }
    
    func updateUIView(_ pdfView: UIView, context: Context) {
        // Cast to PDFView
        guard let pdfView = pdfView as? PDFView else { return }
        
        // Update coordinator state
        context.coordinator.isHighlightModeActive = showHighlightMode
        
        // COMPLETELY disable scrolling when in highlight mode
        if let scrollView = pdfView.pdfScrollView {
            // First approach: disable scroll view completely
            scrollView.isScrollEnabled = !showHighlightMode
            
            // Second approach: freeze content offset when in highlight mode
            if showHighlightMode {
                context.coordinator.savedContentOffset = scrollView.contentOffset
                context.coordinator.isScrollingLocked = true
            } else {
                context.coordinator.isScrollingLocked = false
            }
        }
        
        // Enforce min zoom level when needed
        if pdfView.scaleFactor < context.coordinator.pageFitScaleFactor {
            pdfView.scaleFactor = context.coordinator.pageFitScaleFactor
        }
    }
    
    private func setupPDFView(_ pdfView: PDFView, context: Context) {
        // Basic configuration
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        
        // Set zoom limits to fit page width
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit // Set minimum scale to fit width
        pdfView.maxScaleFactor = 4.0
        pdfView.autoScales = true  // Enable auto-scaling for initial fit
        
        // Store reference to PDF view
        context.coordinator.pdfView = pdfView
        
        // Add gesture recognizers to capture zoom changes and enforce minimum
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinchGesture(_:)))
        pinchGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(pinchGesture)
        
        // Add pan gesture for highlighting using PDFAnnotations
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePanGesture(_:)))
        panGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(panGesture)
        
        // Load document
        if FileManager.default.fileExists(atPath: pdfURL.path) {
            DispatchQueue.global(qos: .userInitiated).async {
                let document = PDFDocument(url: pdfURL)
                
                DispatchQueue.main.async {
                    pdfView.document = document
                    
                    // Set initial zoom to fit page width
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Store the page fit factor for bounce-back
                        let fitFactor = pdfView.scaleFactorForSizeToFit
                        context.coordinator.pageFitScaleFactor = fitFactor
                        
                        // Apply the fit factor
                        pdfView.scaleFactor = fitFactor
                        
                        // Add observer for undo notification
                        NotificationCenter.default.addObserver(
                            context.coordinator,
                            selector: #selector(Coordinator.undoLastHighlightAnnotation),
                            name: NSNotification.Name("UndoLastHighlight"),
                            object: nil
                        )
                    }
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Coordinator modified to handle PDFAnnotations
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: StrictZoomPDFView
        var isHighlightModeActive: Bool = false
        var pdfView: PDFView?
        var pageFitScaleFactor: CGFloat = 1.0
        var lastScale: CGFloat = 1.0
        
        // Add properties for scroll locking
        var isScrollingLocked: Bool = false
        var savedContentOffset: CGPoint = .zero
        
        // Store annotations for undo
        var currentAnnotation: PDFAnnotation?
        var addedAnnotations: [PDFAnnotation] = []
        var currentPage: PDFPage?
        
        init(_ parent: StrictZoomPDFView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        // Handle pinch gesture to enforce minimum zoom
        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            guard let pdfView = self.pdfView else { return }
            
            // Don't allow pinch zooming if highlight mode is active
            if isHighlightModeActive {
                gesture.state = .cancelled
                return
            }
            
            if gesture.state == .began {
                lastScale = pdfView.scaleFactor
            }
            else if gesture.state == .changed {
                // Allow temporary zooming below minimum during gesture for natural feel
                // This gives elasticity to the gesture
                let proposedScale = lastScale * gesture.scale
                pdfView.scaleFactor = proposedScale
            }
            else if gesture.state == .ended || gesture.state == .cancelled {
                // If we're below the minimum zoom, animate smoothly back to the fit scale
                if pdfView.scaleFactor < pageFitScaleFactor {
                    // Get velocity for natural feel
                    let velocity = gesture.velocity
                    let velocityFactor = velocity > 0 ? 1.0 : max(0.5, 1.0 + velocity * 0.2)
                    
                    // Animate with spring physics for a natural bounce
                    UIView.animate(withDuration: 0.4, 
                                   delay: 0, 
                                   usingSpringWithDamping: 0.7, 
                                   initialSpringVelocity: velocityFactor, 
                                   options: [.allowUserInteraction, .curveEaseOut], 
                                   animations: {
                        pdfView.scaleFactor = self.pageFitScaleFactor
                    }, completion: nil)
                }
            }
        }
        
        // Handle scroll events - keep position fixed in highlight mode
        @objc func handleScrollViewDidScroll(_ scrollView: UIScrollView) {
            if isScrollingLocked && isHighlightModeActive {
                // Force scroll view to stay at saved position
                scrollView.contentOffset = savedContentOffset
            }
        }
        
        // Override scrollViewDidScroll for KVO observation
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "contentOffset", let scrollView = object as? UIScrollView {
                if isScrollingLocked && isHighlightModeActive {
                    // Force scroll view to stay at saved position without animation
                    scrollView.contentOffset = savedContentOffset
                }
            }
        }
        
        // Ensure gesture recognizers don't allow scrolling in highlight mode
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // If we're in highlight mode and one is a scroll gesture, PREVENT it
            if isHighlightModeActive {
                // Block scroll gestures when highlighting
                if otherGestureRecognizer is UIPanGestureRecognizer && 
                   otherGestureRecognizer.view is UIScrollView {
                    return false
                }
                
                // Block pinch zooming when highlighting
                if otherGestureRecognizer is UIPinchGestureRecognizer {
                    return false
                }
            }
            
            // Allow simultaneous gestures otherwise
            return true
        }
        
        // Undo the last added highlight annotation
        @objc func undoLastHighlightAnnotation() {
            guard let lastAnnotation = addedAnnotations.popLast(),
                  let page = lastAnnotation.page else { return }
            
            page.removeAnnotation(lastAnnotation)
        }
        
        // Restore the handlePanGesture method that was mistakenly removed
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let pdfView = self.pdfView, isHighlightModeActive else { return }
            
            let location = gesture.location(in: pdfView)
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            let convertedPoint = pdfView.convert(location, to: page)
            
            switch gesture.state {
            case .began:
                // Create a new Ink annotation
                let path = UIBezierPath()
                path.move(to: convertedPoint)
                
                let border = PDFBorder()
                border.lineWidth = 5.0 // Adjust thickness as needed
                
                currentAnnotation = PDFAnnotation(bounds: page.bounds(for: pdfView.displayBox), forType: .ink, withProperties: nil)
                currentAnnotation?.color = UIColor.yellow.withAlphaComponent(0.3)
                currentAnnotation?.border = border
                currentAnnotation?.add(path)
                
                // Add to page and store for undo
                page.addAnnotation(currentAnnotation!)
                self.currentPage = page
                
            case .changed:
                // Add point to the current annotation's path
                guard let annotation = currentAnnotation, let path = annotation.paths?.first else { return }
                path.addLine(to: convertedPoint)
                annotation.remove(path)
                annotation.add(path)
                // Force redraw if needed (usually handled by PDFKit)
                pdfView.layoutDocumentView()
                
            case .ended, .cancelled:
                // Finalize annotation and add to undo stack
                if let finalAnnotation = currentAnnotation {
                    addedAnnotations.append(finalAnnotation)
                }
                currentAnnotation = nil
                currentPage = nil
                
            default:
                break
            }
        }
    }
}

