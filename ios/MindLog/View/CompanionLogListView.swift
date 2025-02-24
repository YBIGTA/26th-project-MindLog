import SwiftUI

struct CompanionLogListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var diaryEntries: [PersonDiaryResponse.PersonDiary] = []  // 기본 목록용
    @State private var fullDiaryEntries: [DiaryResponse] = []  // 전체 정보를 담을 배열
    @State private var isLoading = true
    let personName: String
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Heading(
                    title: "\(personName)와의 기록",
                    buttonIcon: nil,
                    menuItems: []
                ) 
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if fullDiaryEntries.isEmpty {
                                Text("\(personName)와의 기록이 없습니다")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            } else {
                                ForEach(fullDiaryEntries, id: \.id) { diary in
                                    NavigationLink {
                                        LoadingView(diaryId: diary.id)
                                    } label: {
                                        ArchiveCardView(
                                            backgroundImage: getFirstImage(from: diary.images),
                                            filterImage: "glassFilter",
                                            date: formatDate(diary.date),
                                            location: getLocationTag(diary.tags),
                                            place: getPlaceTag(diary.tags),
                                            people: getPeopleTags(diary.tags),
                                            emotions: diary.emotions,
                                            size: .small,
                                            action: {}
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            
            VStack {
                Spacer()
                FloatingButtonContainer(buttons: [
                    FloatingButton(icon: "arrow.left", text: nil, action: {
                        dismiss()
                    })
                ])
                .padding(.bottom, 16)
            }
        }
        .commonBackground()
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await fetchDiariesByPerson()
        }
    }
    
    private func fetchDiariesByPerson() async {
        isLoading = true
        do {
            // 첫 번째 API 호출에서 기본 다이어리 목록을 가져옵니다
            let response = try await DiaryService.shared.getDiariesByPerson(name: personName)
            print("📝 Initial diaries count: \(response.diaries.count)")
            self.diaryEntries = response.diaries
            
            // 각 다이어리의 상세 정보를 가져옵니다
            var fullEntries: [DiaryResponse] = []
            for diary in response.diaries {
                do {
                    let fullDiary = try await DiaryService.shared.getDiary(id: diary.id)
                    print("✅ Successfully fetched diary ID: \(diary.id)")
                    fullEntries.append(fullDiary)
                } catch {
                    print("⚠️ Failed to fetch diary ID \(diary.id): \(error.localizedDescription)")
                    // 개별 다이어리 로드 실패 시에도 계속 진행
                    continue
                }
            }
            
            await MainActor.run {
                self.fullDiaryEntries = fullEntries.sorted { $0.date > $1.date }
                print("📊 Total loaded diaries: \(fullEntries.count)")
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching diaries for \(personName): \(error.localizedDescription)")
            await MainActor.run {
                self.fullDiaryEntries = []
                self.isLoading = false
            }
        }
    }
    
    // Helper functions
    private func getFirstImage(from images: [ImageInfo]) -> String {
        return images.first?.image_url ?? ""
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "yyyy년 M월 d일"
            return formatter.string(from: date)
        }
        return dateString
    }
    
    private func getLocationTag(_ tags: [TagResponse]) -> String? {
        let locationTag = tags.first { $0.type == "도시" }?.tag_name
        print("🌎 Location tag:", locationTag ?? "nil")
        return locationTag?.isEmpty == false ? locationTag : nil
    }
    
    private func getPlaceTag(_ tags: [TagResponse]) -> String? {
        let placeTag = tags.first { $0.type == "장소" }?.tag_name
        print("🏢 Place tag:", placeTag ?? "nil")
        return placeTag?.isEmpty == false ? placeTag : nil
    }
    
    private func getPeopleTags(_ tags: [TagResponse]) -> [String] {
        let peopleTags = tags.filter { $0.type == "인물" }
            .map { $0.tag_name }
            .filter { !$0.isEmpty }
        print("👥 People tags:", peopleTags)
        return peopleTags
    }
    
    private func getEmotionTags(_ tags: [TagResponse]) -> [String] {
        let emotionTags = tags.filter { tag in
            // 감정 관련 태그 타입을 모두 포함
            ["감정", "기분", "emotion", "mood"].contains(tag.type.lowercased())
        }
        .map { $0.tag_name }
        .filter { !$0.isEmpty }
        
        print("❤️ Emotion tags:", emotionTags)
        return emotionTags
    }
}
