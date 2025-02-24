import SwiftUI
import PhotosUI

struct WriteLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var images: [ImageData] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var caption: String = ""
    @State private var showEmotionPicker = false
    @State private var selectedButtonIndex: Int?
    @State private var emotions: [String?] = [nil, nil, nil]
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSavedView = false
    @State private var savedDiaryResponse: DiaryResponse?
    @State private var showErrorAlert = false
    @FocusState private var isCaptionFocused: Bool
    
    private let emotionList: [String] = ["기쁨", "신뢰", "긴장", "놀람", "슬픔", "혐오", "격노", "열망"]
    private let emotionColors: [String: Color] = [
        "기쁨": Color(hex: "#FFD700").opacity(0.6),
        "신뢰": Color(hex: "#4A90E2").opacity(0.6),
        "긴장": Color(hex: "#4A4A4A").opacity(0.6),
        "놀람": Color(hex: "#FF9F1C").opacity(0.6),
        "슬픔": Color(hex: "#5C85D6").opacity(0.6),
        "혐오": Color(hex: "#6B8E23").opacity(0.6),
        "격노": Color(hex: "#E63946").opacity(0.6),
        "열망": Color(hex: "#9B59B6").opacity(0.6)
    ]
    
    // 날짜 포맷터 수정
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"  // "Sat, Feb 22" 형식
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Heading(
                                title: "New Log",
                                buttonIcon: nil,
                                menuItems: []
                            )
                            .padding(.top, 16)
                            
                            Text(dateFormatter.string(from: Date()))
                                .font(.system(size: 17))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 8)
                        
                        PhotoSectionView(
                            images: $images,
                            selectedItems: $selectedItems
                        )
                        
                        EmotionSectionView(
                            emotions: $emotions,
                            showEmotionPicker: $showEmotionPicker,
                            selectedButtonIndex: $selectedButtonIndex,
                            emotionColors: emotionColors,
                            emotionList: emotionList
                        )
                        
                        CaptionSectionView(
                            caption: $caption,
                            isFocused: _isCaptionFocused
                        )
                        
                        Spacer().frame(height: 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        FloatingButton(
                            icon: "xmark",
                            text: nil,
                            action: {
                                isCaptionFocused = false
                                dismiss()
                            }
                        )
                        
                        FloatingButton(
                            icon: "checkmark",
                            text: "Save",
                            action: {
                                isCaptionFocused = false
                                Task {
                                    await saveDiary()
                                }
                            }
                        )
                        .disabled(!emotions.contains { $0 != nil } || images.isEmpty || isLoading)
                        .opacity(!emotions.contains { $0 != nil } || images.isEmpty || isLoading ? 0.5 : 1)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.black
                            .edgesIgnoringSafeArea(.bottom)
                    )
                }
                
                if isLoading {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("오늘 하루를 담고 있는 중입니다\n잠시만 기다려주세요")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarHidden(true)
            .onChange(of: selectedItems) { oldValue, newValue in
                Task {
                    await handleSelectedItemsChange(newValue)
                }
            }
        }
        .fullScreenCover(isPresented: $showSavedView) {
            if let response = savedDiaryResponse {
                SavedLogView(diaryResponse: response, isFromWriteView: true)
            }
        }
        .alert("서버 연결 실패", isPresented: $showErrorAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("잠시 후 다시 시도해주세요.")
        }
    }
    
    private func handleSelectedItemsChange(_ newItems: [PhotosPickerItem]) {
        Task {
            let newItemIds = Set(newItems.compactMap { $0.itemIdentifier })
            images.removeAll { imageData in
                !newItemIds.contains(imageData.id)
            }
            
            for item in newItems {
                if let identifier = item.itemIdentifier,
                   !images.contains(where: { $0.id == identifier }) {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        if let source = CGImageSourceCreateWithData(data as CFData, nil),
                           let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] {
                            
                            // GPS 메타데이터 상세 디버깅
                            if let gpsData = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                                print("\n📍 GPS 메타데이터 발견 - 이미지 ID:", identifier)
                                
                                // 위도 정보
                                if let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
                                   let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double {
                                    print("- 위도: \(latitude)°\(latitudeRef)")
                                }
                                
                                // 경도 정보
                                if let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String,
                                   let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double {
                                    print("- 경도: \(longitude)°\(longitudeRef)")
                                }
                                
                                // 고도 정보
                                if let altitude = gpsData[kCGImagePropertyGPSAltitude as String] as? Double {
                                    print("- 고도: \(altitude)m")
                                }
                                
                                // 시간 정보
                                if let timestamp = gpsData[kCGImagePropertyGPSTimeStamp as String] {
                                    print("- GPS 시간:", timestamp)
                                }
                                
                                // 날짜 정보
                                if let datestamp = gpsData[kCGImagePropertyGPSDateStamp as String] {
                                    print("- GPS 날짜:", datestamp)
                                }
                            } else {
                                print("\n⚠️ GPS 메타데이터 없음 - 이미지 ID:", identifier)
                            }
                            
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    withAnimation {
                                        let imageData = ImageData(
                                            id: identifier,
                                            image: image,
                                            pickerItem: item,
                                            metadata: metadata
                                        )
                                        images.append(imageData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func removeImage(_ imageData: ImageData) {
        if let index = images.firstIndex(of: imageData) {
            images.remove(at: index)
            // 선택된 항목에서도 제거
            if let itemIndex = selectedItems.firstIndex(where: { $0.itemIdentifier == imageData.pickerItem.itemIdentifier }) {
                selectedItems.remove(at: itemIndex)
            }
        }
    }
    
    private func saveDiary() async {
        isLoading = true
        
        do {
            guard !images.isEmpty else {
                errorMessage = "이미지를 선택해주세요."
                showError = true
                isLoading = false
                return
            }
            
            let validEmotions = emotions.compactMap { $0 }
            guard !validEmotions.isEmpty else {
                errorMessage = "감정을 선택해주세요."
                showError = true
                isLoading = false
                return
            }
            
            print("\n📡 서버 전송 직전 상태")
            print("- 전송할 이미지 개수:", images.count)
            
            // GPS 메타데이터 최종 확인
            for (index, imageData) in images.enumerated() {
                print("\n📍 이미지 #\(index + 1) GPS 데이터 확인")
                if let metadata = imageData.metadata,
                   let gpsData = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    
                    // 위도 정보
                    if let latitudeRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
                       let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double {
                        print("- 위도: \(latitude)°\(latitudeRef)")
                    }
                    
                    // 경도 정보
                    if let longitudeRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String,
                       let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double {
                        print("- 경도: \(longitude)°\(longitudeRef)")
                    }
                    
                    // 고도 정보
                    if let altitude = gpsData[kCGImagePropertyGPSAltitude as String] as? Double {
                        print("- 고도: \(altitude)m")
                    }
                    
                    print("✅ GPS 메타데이터 확인 완료")
                } else {
                    print("⚠️ GPS 메타데이터 없음")
                }
            }
            
            print("\n- 선택된 감정:", validEmotions)
            print("- 작성된 캡션:", caption)
            
            // 서버 전송
            let response = try await DiaryService.shared.createDiary(
                date: Date(),
                images: images.map { ($0.image, $0.metadata) },
                emotions: validEmotions,
                text: caption
            )
            
            await MainActor.run {
                savedDiaryResponse = response
                showSavedView = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showErrorAlert = true
                isLoading = false
            }
        }
    }
}

// MARK: - Photo Section
private struct PhotoSectionView: View {
    @Binding var images: [WriteLogView.ImageData]
    @Binding var selectedItems: [PhotosPickerItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photos")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !images.isEmpty {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 10 - images.count,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal)
            
            if images.isEmpty {
                EmptyPhotoView(selectedItems: $selectedItems)
            } else {
                PhotoGalleryView(images: images)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Photo View
private struct EmptyPhotoView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .images,
            photoLibrary: .shared()
        ) {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                
                Text("Add Pictures")
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                
                Text("Select up to 10 photos")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 348)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - Photo Gallery View
private struct PhotoGalleryView: View {
    let images: [WriteLogView.ImageData]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(images) { imageData in
                    Image(uiImage: imageData.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width * 0.6)
                        .frame(height: 348)
                        .clipped()
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 348)
    }
}

// 감정 선택을 위한 새로운 뷰
struct EmotionPickerView: View {
    let emotions: [String]
    let selectedEmotion: String?
    let onSelect: (String?) -> Void
    let selectedEmotions: [String?]
    
    var body: some View {
        NavigationView {
            List {
                // 감정 선택 취소 옵션 추가
                Button(action: {
                    onSelect(nil)
                }) {
                    HStack {
                        Text("선택 안 함")
                            .foregroundColor(.white)
                        Spacer()
                        if selectedEmotion == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(emotions, id: \.self) { emotion in
                    let isSelected = selectedEmotion == emotion
                    let isDisabled = selectedEmotions.contains(emotion) && !isSelected
                    
                    Button(action: {
                        onSelect(emotion)
                    }) {
                        HStack {
                            Text(emotion)
                                .foregroundColor(isDisabled ? .gray : .white)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(isDisabled)
                }
            }
            .background(Color.black)
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Emotion Section
private struct EmotionSectionView: View {
    @Binding var emotions: [String?]
    @Binding var showEmotionPicker: Bool
    @Binding var selectedButtonIndex: Int?
    let emotionColors: [String: Color]
    let emotionList: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emotion")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    Button(action: {
                        if index == emotions.prefix(index).compactMap({ $0 }).count {
                            selectedButtonIndex = index
                            showEmotionPicker = true
                        }
                    }) {
                        Text(emotions[index] ?? (index == emotions.prefix(index).compactMap({ $0 }).count ? "+" : ""))
                            .font(.system(size: 16))
                            .foregroundColor(
                                emotions[index] == nil ? 
                                    (index == emotions.prefix(index).compactMap({ $0 }).count ? .white : .gray) : 
                                    .white
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                emotions[index].map { emotionColors[$0] } ?? 
                                Color.gray.opacity(index == emotions.prefix(index).compactMap({ $0 }).count ? 0.2 : 0.1)
                            )
                            .cornerRadius(8)
                    }
                    .disabled(index > emotions.prefix(index).compactMap({ $0 }).count)
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showEmotionPicker) {
            EmotionPickerView(
                emotions: emotionList,
                selectedEmotion: emotions[selectedButtonIndex ?? 0],
                onSelect: handleEmotionSelection,
                selectedEmotions: emotions
            )
            .presentationDetents([.medium])
        }
    }
    
    private func handleEmotionSelection(_ emotion: String?) {
        if let index = selectedButtonIndex {
            if emotion == nil {
                let remainingEmotions = emotions.compactMap { $0 }
                emotions = [String?](repeating: nil, count: 3)
                for (i, emotion) in remainingEmotions.enumerated() where i != index {
                    emotions[emotions.prefix(i).compactMap({ $0 }).count] = emotion
                }
            } else {
                emotions[index] = emotion
            }
        }
        showEmotionPicker = false
    }
}

// MARK: - Caption Section
private struct CaptionSectionView: View {
    @Binding var caption: String
    @FocusState var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            TextEditor(text: $caption)
                .focused($isFocused)
                .frame(height: 100)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
                .font(.body)
                .padding(.horizontal)
                .overlay(
                    Group {
                        if caption.isEmpty {
                            Text("오늘의 기록을 자유롭게 작성해보세요")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - ImageData Model
extension WriteLogView {
    struct ImageData: Identifiable, Equatable {
        let id: String
        let image: UIImage
        let pickerItem: PhotosPickerItem
        let metadata: [String: Any]?
        
        static func == (lhs: ImageData, rhs: ImageData) -> Bool {
            return lhs.id == rhs.id
        }
    }
}

#Preview {
    WriteLogView()
} 
