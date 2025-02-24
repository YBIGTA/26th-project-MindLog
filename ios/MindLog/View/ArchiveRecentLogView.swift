import SwiftUI

struct ArchiveRecentLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var diaryEntries: [DiaryResponse] = []
    @State private var isLoading = true
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 16) {
                    // 선택된 월 표시
                    Heading(
                        title: formatMonth(from: selectedDate),
                        buttonIcon: "calendar",
                        menuItems: [],
                        onCalendarTap: {
                            showDatePicker = true
                        }
                    )
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                if diaryEntries.isEmpty {
                                    Text("이 달의 기록이 없습니다")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                } else {
                                    ForEach(diaryEntries, id: \.id) { diary in
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
                
                // 플로팅 버튼
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
            .sheet(isPresented: $showDatePicker) {
                MonthYearPickerView(selectedDate: $selectedDate, showDatePicker: $showDatePicker)
                    .presentationDetents([.fraction(0.3)])
            }
            .onChange(of: selectedDate) { _ in
                Task {
                    await fetchDiariesForSelectedDate()
                }
            }
        }
        .task {
            await fetchDiariesForSelectedDate()
        }
    }
    
    private func fetchDiariesForSelectedDate() async {
        isLoading = true
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        do {
            let responses = try await DiaryService.shared.getDiariesByDate(year: year, month: month)
            await MainActor.run {
                self.diaryEntries = responses.sorted { $0.date > $1.date }
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching diaries:", error)
            await MainActor.run {
                self.diaryEntries = []
                self.isLoading = false
            }
        }
    }
    
    // 선택된 월의 다이어리 필터링
    private func filterDiariesForSelectedMonth() -> [DiaryResponse] {
        let calendar = Calendar.current
        let selectedYear = calendar.component(.year, from: selectedDate)
        let selectedMonth = calendar.component(.month, from: selectedDate)
        
        print("🔍 선택된 날짜 - 년: \(selectedYear), 월: \(selectedMonth)")
        
        // 먼저 해당 월의 다이어리들을 필터링
        let filteredDiaries = diaryEntries.filter { diary in
            print("📝 다이어리 날짜 확인 - ID: \(diary.id), Date: \(diary.date)")
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            
            guard let diaryDate = dateFormatter.date(from: diary.date) else {
                print("❌ 날짜 파싱 실패: \(diary.date)")
                return false
            }
            
            let diaryYear = calendar.component(.year, from: diaryDate)
            let diaryMonth = calendar.component(.month, from: diaryDate)
            
            let matches = diaryYear == selectedYear && diaryMonth == selectedMonth
            print("✅ 파싱 성공 - 매칭 결과: \(matches)")
            return matches
        }
        
        // date 기준으로 내림차순 정렬
        return filteredDiaries.sorted { diary1, diary2 in
            diary1.date > diary2.date
        }
    }
    
    // ISO8601 문자열을 Date로 파싱
    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        print("❌ ISO8601 날짜 파싱 실패: \(dateString)")
        return nil
    }
    
    // 선택된 월 포맷팅 (예: "2024년 3월")
    private func formatMonth(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy'년' M'월'"  // 작은따옴표로 감싸서 리터럴로 처리
        return formatter.string(from: date)
    }
    
    // 이미지 URL 배열에서 첫 번째 이미지 선택
    private func getFirstImage(from images: [ImageInfo]) -> String {
        guard let firstImage = images.first else { 
            print("❌ 이미지 배열이 비어있음")
            return "" 
        }
        print("✅ 첫 번째 이미지 URL:", firstImage.image_url)
        return firstImage.image_url
    }
    
    // 날짜 포맷팅 (예: "2024년 2월 17일")
    private func formatDate(_ dateString: String) -> String {
        // ISO 8601 형식의 문자열을 파싱하기 위한 DateFormatter
        let inputFormatter = ISO8601DateFormatter()
        
        // 출력을 위한 DateFormatter
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ko_KR")
        outputFormatter.dateFormat = "yyyy년 M월 d일"
        
        // ISO 8601 문자열을 Date 객체로 변환
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        // ISO 8601 파싱에 실패한 경우, 간단한 문자열 슬라이싱 사용
        let components = dateString.split(separator: "T")
        if let dateComponent = components.first {
            let dateParts = dateComponent.split(separator: "-")
            if dateParts.count == 3,
               let year = dateParts[safe: 0],
               let month = dateParts[safe: 1],
               let day = dateParts[safe: 2] {
                return "\(year)년 \(Int(month) ?? 0)월 \(Int(day) ?? 0)일"
            }
        }
        
        print("❌ 날짜 파싱 실패:", dateString)
        return dateString // 모든 파싱이 실패한 경우 원본 문자열 반환
    }
    
    // 태그 파싱 함수들
    private func getLocationTag(_ tags: [TagResponse]) -> String? {
        let tag = tags.first { $0.type == "도시" }?.tag_name
        return tag?.isEmpty == false ? tag : nil
    }
    
    private func getPlaceTag(_ tags: [TagResponse]) -> String? {
        let tag = tags.first { $0.type == "장소" }?.tag_name
        return tag?.isEmpty == false ? tag : nil
    }
    
    private func getPeopleTags(_ tags: [TagResponse]) -> [String] {
        return tags.filter { $0.type == "인물" }
            .map { $0.tag_name }
            .filter { !$0.isEmpty }
    }
    
    private func getEmotionTags(_ tags: [TagResponse]) -> [String] {
        return tags.filter { $0.type == "감정" }
            .map { $0.tag_name }
            .filter { !$0.isEmpty }
    }
}

// DatePicker 뷰를 MonthYearPickerView로 대체
struct MonthYearPickerView: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    
    private let months = Array(1...12)
    private let years = Array(2020...Calendar.current.component(.year, from: Date()))
    
    init(selectedDate: Binding<Date>, showDatePicker: Binding<Bool>) {
        _selectedDate = selectedDate
        _showDatePicker = showDatePicker
        let calendar = Calendar.current
        _selectedYear = State(initialValue: calendar.component(.year, from: selectedDate.wrappedValue))
        _selectedMonth = State(initialValue: calendar.component(.month, from: selectedDate.wrappedValue))
    }
    
    var body: some View {
        NavigationView {
            HStack {
                // 연도 선택
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(format: "%d년", year))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)
                
                // 월 선택
                Picker("Month", selection: $selectedMonth) {
                    ForEach(months, id: \.self) { month in
                        Text("\(month)월")
                            .tag(month)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationBarItems(
                trailing: Button("완료") {
                    var components = DateComponents()
                    components.year = selectedYear
                    components.month = selectedMonth
                    components.day = 1
                    
                    if let newDate = Calendar.current.date(from: components) {
                        selectedDate = newDate
                    }
                    showDatePicker = false
                }
            )
        }
    }
}

// 미리보기
struct ArchiveRecentLogView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveRecentLogView()
    }
}
