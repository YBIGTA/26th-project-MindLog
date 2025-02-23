import SwiftUI

struct ArchiveFeelingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String? = nil
    @State private var dragOffset = CGSize.zero

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

    // 📌 감정별 로그 개수 (파이 차트)
    let categoryLogCounts: [String: Int] = [
        "Joy": 10, "Trust": 8, "Fear": 5, "Surprise": 7,
        "Sadness": 6, "Disgust": 4, "Anger": 9, "Anticipation": 8
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
                
                // ✅ 차트 영역
                FeelingChartView(selectedCategory: selectedCategory, categoryLogCounts: categoryLogCounts, monthlyLogs: monthlyLogs)

                // ✅ 감정 선택 버튼 (2x4 그리드)
                FeelingCategoryGrid(categories: categories, selectedCategory: $selectedCategory)
                Spacer()
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
    }
}

// ✅ 차트만 담당하는 서브뷰 (PieChart & BarChart 선택)
struct FeelingChartView: View {
    let selectedCategory: String?
    let categoryLogCounts: [String: Int]
    let monthlyLogs: [String: [Int]]

    var body: some View {
        if let selectedCategory = selectedCategory, let monthlyData = monthlyLogs[selectedCategory] {
            BarChartContainer(title: selectedCategory, category: selectedCategory, data: monthlyData)
        } else {
            PieChartContainer(title: "State of Mind", data: categoryLogCounts)
        }
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

// ✅ 미리보기
struct ArchiveFeelingView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveFeelingView()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
