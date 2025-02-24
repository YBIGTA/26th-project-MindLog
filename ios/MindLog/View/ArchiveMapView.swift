import SwiftUI
import MapKit

// 📌 로그 데이터 모델 (Identifiable 추가)
struct LogItem: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let image: String
    let category: String  // ✅ 카테고리 추가
}

// ImageItem과 TagItem 구조체 정의 (또는 관련 파일 import)
struct ImageItem: Identifiable {
    let id: String
    let image_url: String
}

struct TagItem: Identifiable {
    let id: String
    let name: String
}

struct ArchiveMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5),
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )
    @State private var placeGroups: [PlaceGroup] = []
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedDiaryResponse: DiaryResponse? = nil  // DiaryEntry 대신 DiaryResponse 사용
    @State private var showDiaryDetail = false
    
    // 필터링된 다이어리를 계산하는 함수를 별도로 분리
    private func getFilteredDiaries() -> [PlaceDiary] {
        if let selectedCategory = selectedCategory {
            // 선택된 카테고리의 다이어리만 가져옴
            return placeGroups
                .first { $0.category == selectedCategory }?
                .diaries
                .filter { diary in
                    diary.latitude != nil && diary.longitude != nil
                } ?? []
        } else {
            // 전체 다이어리 표시 (중복 제거)
            let allDiaries = placeGroups.flatMap { $0.diaries }
            
            // ID를 기준으로 중복 제거
            var uniqueDiaries: [PlaceDiary] = []
            var seenIds = Set<String>()
            
            for diary in allDiaries {
                if !seenIds.contains(diary.id) {
                    seenIds.insert(diary.id)
                    if diary.latitude != nil && diary.longitude != nil {
                        uniqueDiaries.append(diary)
                    }
                }
            }
            
            return uniqueDiaries
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map 뷰에서 필터링된 다이어리 사용
                Map(coordinateRegion: $region, annotationItems: getFilteredDiaries()) { diary in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(
                        latitude: diary.latitude ?? 0,
                        longitude: diary.longitude ?? 0
                    )) {
                        LogOnMap(
                            latitude: diary.latitude ?? 0,
                            longitude: diary.longitude ?? 0,
                            image: diary.thumbnail_url
                        ) {
                            Task {
                                await loadSelectedDiary(id: diary.id)
                            }
                        }
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 16) {
                    Heading(title: "Place", buttonIcon: nil, menuItems: [])
                    
                    Spacer()
                    
                    PlaceCategoryGrid(
                        placeGroups: placeGroups,
                        selectedCategory: $selectedCategory
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 60)
                }
                
                VStack {
                    Spacer()
                    FloatingButtonContainer(buttons: [
                        FloatingButton(icon: "arrow.left", text: nil, action: {
                            dismiss()
                        })
                    ])
                    .padding(.bottom, 6)
                }
            }
            .navigationDestination(isPresented: $showDiaryDetail) {
                if let diaryResponse = selectedDiaryResponse {
                    SavedLogView(diaryResponse: diaryResponse, isFromWriteView: false)
                }
            }
        }
        .commonBackground()
        .task {
            await loadPlaceData()
        }
        .alert("에러", isPresented: $showError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadPlaceData() async {
        isLoading = true
        do {
            let response = try await DiaryService.shared.getDiariesByPlace()
            await MainActor.run {
                placeGroups = response.places
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                isLoading = false
            }
        }
    }
    
    private func loadSelectedDiary(id: String) async {
        do {
            let response = try await DiaryService.shared.getDiary(id: id)
            await MainActor.run {
                self.selectedDiaryResponse = response  // DiaryResponse를 직접 저장
                self.showDiaryDetail = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
}

// 카테고리 그리드를 별도의 뷰로 분리
struct PlaceCategoryGrid: View {
    let placeGroups: [PlaceGroup]
    @Binding var selectedCategory: String?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(placeGroups, id: \.category) { group in
                ExpandableCategoryButton(
                    category: (group.category, "\(group.diary_count)개의 로그"),
                    onCategorySelected: { selected in
                        selectedCategory = (selectedCategory == selected) ? nil : selected
                    },
                    isSelected: selectedCategory == group.category,
                    backgroundColor: Color(white: 0.2),
                    onBackPressed: {
                        selectedCategory = nil
                    }
                )
            }
        }
    }
}

// ✅ 미리보기
struct ArchiveMapView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveMapView()
    }
}
