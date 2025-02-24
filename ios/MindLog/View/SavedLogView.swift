import SwiftUI
import Foundation
import AVFoundation

struct SavedLogView: View {
    @Environment(\.dismiss) private var dismiss
    let diaryResponse: DiaryResponse
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying: Bool = false
    @State private var selectedImage: String?
    @State private var showFullScreenImage = false
    let isFromWriteView: Bool
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 상단 헤더
                    VStack(alignment: .leading, spacing: 4) {
                        DiaryTitle(
                            title: formatDateToKorean(diaryResponse.date),
                            buttonIcon: nil,
                            menuItems: []
                        )
                    }
                    .padding(.bottom, 30)
                    
                    // 이미지 갤러리
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(diaryResponse.images, id: \.image_url) { imageInfo in
                                if let url = URL(string: imageInfo.image_url) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 237, height: 348)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 237, height: 348)
                                                .clipped()
                                                .cornerRadius(10)
                                                .onTapGesture {
                                                    selectedImage = imageInfo.image_url
                                                    showFullScreenImage = true
                                                }
                                        case .failure:
                                            Color.gray
                                                .frame(width: 237, height: 348)
                                                .cornerRadius(10)
                                        @unknown default:
                                            Color.gray
                                                .frame(width: 237, height: 348)
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 6)
                
                // 태그 컨테이너
                VStack(spacing: 5) {
                    // 모든 태그들을 하나의 배열로 합치기
                    let allTags = diaryResponse.tags.map { tag -> AnyView in
                        switch tag.type {
                        case "장소":
                            return AnyView(PlaceTag(placeName: tag.tag_name, size: .big))
                        case "도시":
                            return AnyView(LocationTag(locationName: tag.tag_name, size: .big))
                        case "인물":
                            return AnyView(PersonTag(personID: tag.tag_name, size: .big))
                        default:
                            return AnyView(TagView(text: tag.tag_name, iconName: "tag.fill", size: .big))
                        }
                    } + diaryResponse.emotions.map { emotion in
                        AnyView(EmotionTag(emotion: emotion, size: .big))
                    }
                    
                    // 태그들을 4개씩 그룹화
                    let rows = stride(from: 0, to: allTags.count, by: 4).map {
                        Array(allTags[($0)..<min($0 + 4, allTags.count)])
                    }
                    
                    // 각 행을 중앙 정렬하여 표시
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        HStack(spacing: 5) {
                            ForEach(0..<rows[rowIndex].count, id: \.self) { colIndex in
                                rows[rowIndex][colIndex]
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 24)
                
                // 캡션 텍스트
                if let text = diaryResponse.text, !text.isEmpty {
                    Text(text)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.horizontal, 8)
                        .padding(.top, 18)
                }
                
                MusicButton(
                    albumArtwork: "lucy_album",
                    artistName: "LUCY",
                    songTitle: "아지랑이",
                    isPlaying: isPlaying,
                    action: togglePlayback
                )
                .padding(.top, 18)
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(EmotionBackground(emotion: diaryResponse.emotions.first ?? ""))
        }
        .overlay(
            FloatingButtonContainer(buttons: [
                FloatingButton(
                    icon: "arrow.left",
                    text: nil,
                    action: {
                        if isFromWriteView {
                            // WriteLogView에서 온 경우
                            if let window = UIApplication.shared.windows.first {
                                window.rootViewController?.dismiss(animated: true)
                            }
                        } else {
                            // MainView에서 온 경우
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                ),
                FloatingButton(
                    icon: "square.and.arrow.up",
                    text: "Share",
                    action: { 
                        print("Share tapped")
                    }
                )
            ])
            .padding(.bottom, 16),
            alignment: .bottom
        )
        .sheet(isPresented: $showFullScreenImage) {
            if let imageUrlString = selectedImage, 
               let imageUrl = URL(string: imageUrlString) {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .foregroundColor(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .edgesIgnoringSafeArea(.all)
                        case .failure:
                            Text("이미지를 불러올 수 없습니다")
                                .foregroundColor(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    // 닫기 버튼
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                showFullScreenImage = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .padding(20)
                            }
                        }
                        Spacer()
                    }
                }
                .background(Color.black)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupAudio()
            // 1초 후에 음악 재생
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                audioPlayer?.play()
                isPlaying = true
            }
        }
        .onDisappear {
            audioPlayer?.stop()
            isPlaying = false
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    private func setupAudio() {
        guard let path = Bundle.main.path(forResource: "lucy", ofType: "m4a") else {
            print("음악 파일을 찾을 수 없습니다.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.prepareToPlay()
        } catch {
            print("오디오 플레이어 초기화 실패:", error)
        }
    }
    
    private func formatDateToKorean(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        inputFormatter.locale = Locale(identifier: "ko_KR")
        inputFormatter.timeZone = TimeZone.current
        
        guard let date = inputFormatter.date(from: dateString) else {
            // 첫 번째 포맷 실패 시 다른 포맷 시도
            inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            guard let date = inputFormatter.date(from: dateString) else {
                // 모든 파싱 시도 실패 시 현재 날짜 사용
                return "날짜 형식 오류"
            }
            return formatDate(date)
        }
        
        return formatDate(date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        return "\(year)년 \(month)월 \(day)일"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        
        guard let date = inputFormatter.date(from: dateString) else { return dateString }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "EEE, MMM d"
        return outputFormatter.string(from: date)
    }
}

// 감정에 따른 배경을 적용하는 ViewModifier
struct EmotionBackground: ViewModifier {
    let emotion: String
    
    func body(content: Content) -> some View {
        Group {
            switch emotion {
            case "분노":
                content.angerBackground()
            case "신뢰":
                content.trustBackground()
            case "놀람":
                content.surpriseBackground()
            case "슬픔":
                content.sadnessBackground()
            case "기쁨":
                content.joyBackground()
            case "공포":
                content.fearBackground()
            case "혐오":
                content.disgustBackground()
            case "기대":
                content.anticipationBackground()
            default:
                content.commonBackground()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    // 미리보기용 샘플 데이터
    let sampleTags = [
        TagResponse(
            id: "1",
            type: "장소",
            tag_name: "카페"
        ),
        TagResponse(
            id: "2",
            type: "활동",
            tag_name: "데이트"
        ),
        TagResponse(
            id: "3",
            type: "장소",
            tag_name: "공원"
        ),
        TagResponse(
            id: "4",
            type: "도시",
            tag_name: "서울"
        )
    ]
    
    let sampleResponse = DiaryResponse(
        id: "1",
        date: "2024-02-13T12:00:00.000000",
        images: [
            ImageInfo(image_url: "https://picsum.photos/400/600"),
            ImageInfo(image_url: "https://picsum.photos/400/601")
        ],
        emotions: ["기쁨", "설렘"],
        text: "오늘은 정말 좋은 하루였다. 새로운 카페를 발견했고, 맛있는 커피를 마셨다. 오랜만에 여유로운 시간을 보낼 수 있어서 행복했다.",
        tags: sampleTags,
        created_at: "2024-02-13T12:00:00.000000"
    )
    
    SavedLogView(diaryResponse: sampleResponse, isFromWriteView: false)
} 

