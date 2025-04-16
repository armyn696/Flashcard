//
//  ContentView.swift
//  Flashcard
//
//  Created by Armin Ziaee on 1/26/1404 AP.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var inputText: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var flashcards: [Flashcard] = []
    @State private var isLoading = false
    @State private var showImagePicker = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Flashcard Generator")
                .font(.largeTitle)
                .bold()
            TextField("Enter text or select a photo", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button(action: { showImagePicker = true }) {
                Text("Pick a Photo")
            }
            if isLoading {
                ProgressView()
            } else if !flashcards.isEmpty {
                SwipeableFlashcardView(flashcards: flashcards)
            }
            Button(action: generateFlashcards) {
                Text("Generate Flashcards")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isLoading || (inputText.isEmpty && selectedImage == nil))
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, onImagePicked: { image in
                VisionTextRecognizer.recognizeText(from: image) { text in
                    DispatchQueue.main.async {
                        inputText = text ?? ""
                    }
                }
            })
        }
        .padding()
    }
    
    func generateFlashcards() {
        isLoading = true
        errorMessage = nil
        let text = inputText
        GeminiAPI.shared.generateFlashcards(from: text) { result in
            isLoading = false
            switch result {
            case .success(let cards):
                flashcards = cards
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct SwipeableFlashcardView: View {
    @State var flashcards: [Flashcard]
    @State private var currentIndex = 0
    var body: some View {
        ZStack {
            if currentIndex < flashcards.count {
                FlashcardView(card: flashcards[currentIndex])
                    .transition(.slide)
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if abs(value.translation.width) > 100 {
                                    withAnimation {
                                        currentIndex += 1
                                    }
                                }
                            }
                    )
            } else {
                Text("No more cards!")
            }
        }
        .frame(height: 300)
    }
}

struct FlashcardView: View {
    let card: Flashcard
    @State private var showAnswer = false
    var body: some View {
        VStack {
            Text(showAnswer ? card.answer : card.question)
                .font(.title)
                .padding()
            Button(showAnswer ? "Show Question" : "Show Answer") {
                showAnswer.toggle()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yellow.opacity(0.3))
        .cornerRadius(16)
        .shadow(radius: 4)
        .padding()
    }
}

// ImagePicker using PHPickerViewController
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                if let uiImage = image as? UIImage {
                    DispatchQueue.main.async {
                        self.parent.image = uiImage
                        self.parent.onImagePicked(uiImage)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
