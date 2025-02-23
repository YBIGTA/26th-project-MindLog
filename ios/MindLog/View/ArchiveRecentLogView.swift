import SwiftUI

struct ArchiveRecentLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var diaryEntries: [DiaryResponse] = []
    @State private var isLoading = true
    @State private var selectedDate = Date() // 선택된 날짜
    @State private var showDatePicker = false // DatePicker 표시 여부
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 16) {
                    // 선택된 월 표시
                    let formattedMonth = formatMonth(from: selectedDate)
                    Heading(
                        title: formattedMonth,
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
                                ForEach(filteredDiaries, id: \.id) { diary in
                                    NavigationLink {
                                        LoadingView(diaryId: diary.id)
                                    } label: {
                                        ArchiveCardView(
                                            backgroundImage: getFirstImage(from: diary.image_urls),
                                            filterImage: "glassFilter",
                                            date: formatDate(diary.date),
                                            location: getLocationTag(diary.tags),
                                            place: getPlaceTag(diary.tags),
                                            people: getPeopleTags(diary.tags),
                                            size: .small,
                                            action: {}
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
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
            }
        }
        .task {
            await fetchDiaries()
        }
    }
    
    // 선택된 년월에 해당하는 다이어리만 필터링
    private var filteredDiaries: [DiaryResponse] {
        let calendar = Calendar.current
        let selectedYear = calendar.component(.year, from: selectedDate)
        let selectedMonth = calendar.component(.month, from: selectedDate)
        
        return diaryEntries.filter { diary in
            guard let diaryDate = parseISO8601Date(diary.date) else { return false }
            let diaryYear = calendar.component(.year, from: diaryDate)
            let diaryMonth = calendar.component(.month, from: diaryDate)
            return diaryYear == selectedYear && diaryMonth == selectedMonth
        }
    }
    
    // ISO8601 문자열을 Date로 파싱
    private func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    // 선택된 월 포맷팅 (예: "2024년 3월")
    private func formatMonth(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy'년' M'월'"  // 작은따옴표로 감싸서 리터럴로 처리
        return formatter.string(from: date)
    }
    
    // 이미지 URL 배열에서 첫 번째 이미지 선택
    private func getFirstImage(from urls: [String]) -> String {
        guard !urls.isEmpty else { 
            print("❌ 이미지 URL 배열이 비어있음")
            return "" 
        }
        let firstUrl = urls[0]
        print("✅ 선택된 이미지 URL:", firstUrl)
        return firstUrl
    }
    
    private func fetchDiaries() async {
        do {
            let responses = try await DiaryService.shared.getDiaries()
            print("📍 받아온 다이어리 개수:", responses.count)
            for (index, diary) in responses.enumerated() {
                print("다이어리 \(index + 1) 이미지 URLs:", diary.image_urls)
            }
            
            await MainActor.run {
                self.diaryEntries = responses.sorted { 
                    $0.date > $1.date 
                }
                self.isLoading = false
            }
        } catch {
            print("❌ Error fetching diaries:", error)
            await MainActor.run {
                self.isLoading = false
            }
        }
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
    private func getLocationTag(_ tags: [TagResponse]) -> String {
        return tags.first { $0.type == "도시" }?.tag_name ?? ""
    }
    
    private func getPlaceTag(_ tags: [TagResponse]) -> String {
        return tags.first { $0.type == "장소" }?.tag_name ?? ""
    }
    
    private func getPeopleTags(_ tags: [TagResponse]) -> [String] {
        return tags.filter { $0.type == "인물" }.map { $0.tag_name }
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
