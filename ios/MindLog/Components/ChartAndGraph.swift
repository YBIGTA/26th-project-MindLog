import SwiftUI
import Charts


struct PieChart: View {
    let data: [String: Int]

    // ✅ 감정별 헥스 색상 매핑 (투명도 60% 적용)
    let emotionHexColors: [String: String] = [
        "Joy": "#FFD700",         // 골드
        "Trust": "#4A90E2",       // 블루
        "Fear": "#4A4A4A",        // 다크 그레이
        "Surprise": "#FF9F1C",    // 오렌지
        "Sadness": "#5C85D6",     // 블루
        "Disgust": "#6B8E23",     // 올리브 그린
        "Anger": "#E63946",       // 레드
        "Anticipation": "#9B59B6" // 퍼플
    ]

    var body: some View {
        Chart {
            ForEach(data.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                SectorMark(
                    angle: .value("Count", value),
                    innerRadius: .ratio(0.35), // ✅ 내부까지 채우기
                    outerRadius: .ratio(1.0)
                )
                .foregroundStyle(Color(hex: emotionHexColors[key] ?? "#FFFFFF").opacity(0.6)) // ✅ 색상 + 투명도 60%
                .cornerRadius(6) // ✅ 코너 부드럽게
            }
        }
        .chartLegend(.hidden)
        .frame(height: 180)
        .padding()
    }
}


struct PieChartContainer: View {
    let title: String
    let data: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            // 📌 타이틀 바
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default)) // ✅ SF Pro Display Medium 13pt
                    .foregroundColor(Color(hex: "D2D2D2")) // ✅ #D2D2D2 색상 적용
                    .padding(.leading, 16)
                    .padding(.top, 12)
                Spacer()
                Text("Last 365 Days")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "007AFF"))
                    .padding(.trailing, 16)
                    .padding(.top, 12)
            }

            // 📌 파이 차트
            PieChart(data: data)
                .frame(height: 240) // ✅ 차트 높이 조정
                .padding(.bottom, 12) // ✅ 차트와 하단 간격 추가
        }
        .frame(maxWidth: .infinity) // ✅ 높이 강제 조정
        .frame(height: 360)
        .background(
            Color.black.opacity(0.75) // ✅ 진회색 + 투명도 75%
                .cornerRadius(12) // ✅ 둥근 모서리 추가
        )
        .padding(.horizontal, 16) // ✅ 좌우 여백 추가
    }
}

// ✅ 미리보기
struct PieChartContainer_Previews: PreviewProvider {
    static var previews: some View {
        PieChartContainer(
            title: "State of Mind",
            data: [
                "Joy": 10, "Trust": 8, "Fear": 5, "Surprise": 7,
                "Sadness": 6, "Disgust": 4, "Anger": 9, "Anticipation": 8
            ]
        )
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}


struct BarChartView: View {
    let category: String
    let data: [Int]

    // ✅ 감정별 헥스 색상 매핑
    let emotionHexColors: [String: String] = [
        "Joy": "#FFD700",
        "Trust": "#4A90E2",
        "Fear": "#4A4A4A",
        "Surprise": "#FF9F1C",
        "Sadness": "#5C85D6",
        "Disgust": "#6B8E23",
        "Anger": "#E63946",
        "Anticipation": "#9B59B6"
    ]

    var body: some View {
        let barColor = Color(hex: emotionHexColors[category] ?? "#FFFFFF")

        VStack(spacing: 0) {
            // ✅ 차트
            Chart {
                ForEach(Array(monthAbbreviations.enumerated()), id: \.offset) { index, month in
                    BarMark(
                        x: .value("Month", month),
                        y: .value("Logs", data[index])
                    )
                    .foregroundStyle(barColor)
                    .clipShape(Capsule()) // ✅ 막대 둥글게
                    .annotation(position: .overlay) {
                        Capsule()
                            .fill(barColor)
                            .frame(width: 7) // ✅ 막대 폭 제한
                    }
                }
            }
            .chartXScale(domain: monthAbbreviations)
            .chartXAxis {
                AxisMarks(values: monthAbbreviations) { value in
                    AxisValueLabel(anchor: .top) {
                        if let month = value.as(String.self) {
                            Text(month)
                                .rotationEffect(.degrees(-45)) // ✅ 반대로 회전
                                .offset(y: 9)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 200)

        }
        .padding()
    }

    // ✅ 월 이름 배열 (Jan - Dec)
    private let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
}


struct BarChartContainer: View {
    let title: String
    let category: String
    let data: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            // 📌 타이틀 바
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default)) // ✅ SF Pro Display Medium 13pt
                    .foregroundColor(Color(hex: "D2D2D2")) // ✅ #D2D2D2 색상 적용
                    .padding(.leading, 16)
                    .padding(.top, 12)
                Spacer()
                Text("Last 365 Days")
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "007AFF")) // ✅ 파란색 강조
                    .padding(.trailing, 16)
                    .padding(.top, 12)
            }

            // 📌 바 차트
            BarChartView(category: category, data: data)
                .frame(height: 240) // ✅ 차트 높이 조정
                .padding(.bottom, 12) // ✅ 차트와 하단 간격 추가
        }
        .frame(maxWidth: .infinity) // ✅ 높이 강제 조정
        .frame(height: 360)
        .background(
            Color.black.opacity(0.75) // ✅ 진회색 + 투명도 75%
                .cornerRadius(12) // ✅ 둥근 모서리 추가
        )
        .padding(.horizontal, 16) // ✅ 좌우 여백 추가
    }
}

// ✅ 미리보기
struct BarChartContainer_Previews: PreviewProvider {
    static var previews: some View {
        BarChartContainer(
            title: "Monthly Log Trends",
            category: "Joy",
            data: [2, 1, 3, 4, 2, 5, 3, 6, 7, 5, 3, 4]
        )
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}

//// ✅ 미리보기
//struct BarChartView_Previews: PreviewProvider {
//    static var previews: some View {
//        BarChartView(category: "Joy", data: [2, 1, 3, 4, 2, 5, 3, 6, 7, 5, 3, 4])
//            .preferredColorScheme(.dark)
//            .previewLayout(.sizeThatFits)
//    }
//}



struct PieChartView_Previews: PreviewProvider {
    static var previews: some View {
        PieChart(data: [
            "Joy": 10, "Trust": 8, "Fear": 5, "Surprise": 7,
            "Sadness": 6, "Disgust": 4, "Anger": 9, "Anticipation": 8
        ])
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}


