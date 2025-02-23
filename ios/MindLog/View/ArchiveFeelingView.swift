import SwiftUI

struct ArchiveFeelingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String? = nil
    @State private var dragOffset = CGSize.zero
    @State private var emotionRatios: [String: Double] = [:]
    @State private var isLoading = true
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showYearPicker = false

    // 📌 감정 카테고리 목록
    let categories: [(String, String)] = [
        ("Joy", "기쁨과 만족"),
        ("Trust", "감탄과 수용"),
        ("Fear", "공포와 긴장"),
        ("Surprise", "경이와 놀람"),
        ("Sadness", "슬픔과 우울"),
        ("Disgust", "혐오와 지루"),
        ("Anger", "격노와 불쾌"),
        ("Anticipation", "열망과 호기심")
    ]

    // 📌 감정별 월별 로그 개수 (막대 그래프)
    let monthlyLogs: [String: [Int]] = [
        "Joy": [2, 1, 3, 4, 2, 5, 3, 6, 7, 5, 3, 4],
        "Trust": [3, 2, 2, 3, 4, 3, 5, 2, 6, 7, 4, 5],
        "Fear": [1, 2, 3, 1, 2, 3, 4, 2, 1, 2, 3, 2],
        "Surprise": [2, 2, 4, 3, 2, 5, 3, 4, 5, 3, 2, 6],
        "Sadness": [1, 1, 2, 3, 2, 2, 3, 2, 4, 5, 3, 1],
        "Disgust": [1, 2, 1, 2, 3, 1, 2, 1, 3, 2, 1, 2],
        "Anger": [3, 3, 2, 4, 5, 3, 6, 5, 4, 3, 2, 5],
        "Anticipation": [2, 2, 3, 4, 5, 3, 2, 4, 5, 3, 2, 4]
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Heading(title: "Feeling", buttonIcon: nil, menuItems: [])
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else {
                    FeelingChartView(
                        selectedCategory: selectedCategory,
                        categoryLogCounts: convertRatiosToCount(emotionRatios),
                        monthlyLogs: monthlyLogs,
                        selectedYear: selectedYear,
                        onYearChange: { year in
                            selectedYear = year
                            showYearPicker = true
                        }
                    )
                    .sheet(isPresented: $showYearPicker) {
                        YearPickerView(
                            selectedYear: $selectedYear,
                            showPicker: $showYearPicker,
                            onYearSelected: { year in
                                Task {
                                    isLoading = true
                                    await fetchEmotionRatios()
                                }
                            }
                        )
                        .presentationDetents([.fraction(0.3)])
                    }
                    
                    FeelingCategoryGrid(categories: categories, selectedCategory: $selectedCategory)
                    Spacer()
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
        .task {
            await fetchEmotionRatios()
        }
    }
    
    private func fetchEmotionRatios() async {
        do {
            print("📊 감정 비율 요청 시작 - 선택된 연도: \(selectedYear)")
            let response = try await DiaryService.shared.getFeelingRatio(year: selectedYear)
            
            print("✅ 받아온 감정 비율 데이터:")
            print("- 기쁨: \(response.기쁨)")
            print("- 신뢰: \(response.신뢰)")
            print("- 긴장: \(response.긴장)")
            print("- 놀람: \(response.놀람)")
            print("- 슬픔: \(response.슬픔)")
            print("- 혐오: \(response.혐오)")
            print("- 격노: \(response.격노)")
            print("- 열망: \(response.열망)")
            
            await MainActor.run {
                emotionRatios = [
                    "기쁨": response.기쁨,
                    "신뢰": response.신뢰,
                    "긴장": response.긴장,
                    "놀람": response.놀람,
                    "슬픔": response.슬픔,
                    "혐오": response.혐오,
                    "격노": response.격노,
                    "열망": response.열망
                ]
                isLoading = false
            }
        } catch {
            print("❌ 감정 비율 데이터 가져오기 실패:")
            print("- 에러 내용:", error)
            await MainActor.run {
                emotionRatios = [:]  // 에러 시 빈 데이터로 설정
                isLoading = false
            }
        }
    }
    
    private func convertRatiosToCount(_ ratios: [String: Double]) -> [String: Int] {
        var counts: [String: Int] = [:]
        let emotionMapping = [
            "기쁨": "Joy",
            "신뢰": "Trust",
            "긴장": "Fear",
            "놀람": "Surprise",
            "슬픔": "Sadness",
            "혐오": "Disgust",
            "격노": "Anger",
            "열망": "Anticipation"
        ]
        
        for (koreanEmotion, ratio) in ratios {
            if let englishEmotion = emotionMapping[koreanEmotion] {
                counts[englishEmotion] = Int(ratio)
            }
        }
        return counts
    }
}

// ✅ 차트만 담당하는 서브뷰 (PieChart & BarChart 선택)
struct FeelingChartView: View {
    let selectedCategory: String?
    let categoryLogCounts: [String: Int]
    let monthlyLogs: [String: [Int]]
    let selectedYear: Int
    let onYearChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            // 연도 선택 버튼은 항상 표시
            HStack {
                Text(selectedCategory ?? "State of Mind")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "D2D2D2"))
                    .padding(.leading, 16)
                    .padding(.top, 12)
                Spacer()
                
                // 연도 선택 버튼
                Button(action: {
                    onYearChange(selectedYear)
                }) {
                    Text(String(selectedYear))
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(Color(hex: "007AFF"))
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
            }

            // 데이터 유무에 따른 조건부 렌더링
            if categoryLogCounts.values.allSatisfy({ $0 == 0 }) {
                Text("해당 연도의 기록이 없습니다")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
            } else if let selectedCategory = selectedCategory, let monthlyData = monthlyLogs[selectedCategory] {
                BarChartView(category: selectedCategory, data: monthlyData)
                    .frame(height: 240)
                    .padding(.bottom, 12)
            } else {
                PieChart(data: categoryLogCounts)
                    .frame(height: 240)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .background(
            Color.black.opacity(0.75)
                .cornerRadius(12)
        )
        .padding(.horizontal, 16)
    }
}

// ✅ 감정 카테고리 버튼 (2x4 그리드)
struct FeelingCategoryGrid: View {
    let categories: [(String, String)]
    @Binding var selectedCategory: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(categories, id: \.0) { category in
                ExpandableCategoryButton(
                    category: category,
                    onCategorySelected: { selected in
                        selectedCategory = selected
                    },
                    isSelected: selectedCategory == category.0
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 40)
    }
}

// MARK: - Preview
struct ArchiveFeelingView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveFeelingView()
            .preferredColorScheme(.dark)
    }
}

// Preview 환경 체크를 위한 extension
extension ProcessInfo {
    var isPreviewing: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
