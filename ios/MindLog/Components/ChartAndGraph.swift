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
    @State private var selectedYear: Int
    @State private var showYearPicker = false
    let onYearChange: (Int) -> Void  // 연도 변경 시 호출될 콜백
    
    init(title: String, data: [String: Int], onYearChange: @escaping (Int) -> Void) {
        self.title = title
        self.data = data
        self.onYearChange = onYearChange
        // 현재 연도를 기본값으로 설정
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            // 📌 타이틀 바
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "D2D2D2"))
                    .padding(.leading, 16)
                    .padding(.top, 12)
                Spacer()
                
                Button(action: {
                    showYearPicker = true
                }) {
                    Text(String(selectedYear))
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(Color(hex: "007AFF"))
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
                .sheet(isPresented: $showYearPicker) {
                    YearPickerView(
                        selectedYear: $selectedYear,
                        showPicker: $showYearPicker,
                        onYearSelected: { year in
                            onYearChange(year)
                        }
                    )
                    .presentationDetents([.fraction(0.3)])  // 화면 높이의 1/3로 설정
                }
            }

            // 📌 파이 차트
            PieChart(data: data)
                .frame(height: 240)
                .padding(.bottom, 12)
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

// 연도 선택을 위한 Picker View
struct YearPickerView: View {
    @Binding var selectedYear: Int
    @Binding var showPicker: Bool
    let onYearSelected: (Int) -> Void
    
    private let years: [Int] = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear-5)...currentYear).reversed()
    }()
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Year", selection: $selectedYear) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    showPicker = false
                },
                trailing: Button("Done") {
                    onYearSelected(selectedYear)
                    showPicker = false
                }
            )
        }
        .preferredColorScheme(.dark)
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
            ],
            onYearChange: { _ in }
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
    @State private var selectedYear: Int
    @State private var showYearPicker = false
    let onYearChange: (Int) -> Void

    init(title: String, category: String, data: [Int], selectedYear: Int, onYearChange: @escaping (Int) -> Void) {
        self.title = title
        self.category = category
        self.data = data
        _selectedYear = State(initialValue: selectedYear)
        self.onYearChange = onYearChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 48) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundColor(Color(hex: "D2D2D2"))
                    .padding(.leading, 16)
                    .padding(.top, 12)
                Spacer()
                Button(action: {
                    showYearPicker = true
                }) {
                    Text(String(selectedYear))
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(Color(hex: "007AFF"))
                }
                .padding(.trailing, 16)
                .padding(.top, 12)
                .sheet(isPresented: $showYearPicker) {
                    YearPickerView(
                        selectedYear: $selectedYear,
                        showPicker: $showYearPicker,
                        onYearSelected: { year in
                            onYearChange(year)
                        }
                    )
                    .presentationDetents([.fraction(0.3)])
                }
            }

            if data.isEmpty || data.allSatisfy({ $0 == 0 }) {
                Text("해당 연도의 기록이 없습니다")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                BarChartView(category: category, data: data)
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

// ✅ 미리보기
struct BarChartContainer_Previews: PreviewProvider {
    static var previews: some View {
        BarChartContainer(
            title: "Monthly Log Trends",
            category: "Joy",
            data: [2, 1, 3, 4, 2, 5, 3, 6, 7, 5, 3, 4],
            selectedYear: Calendar.current.component(.year, from: Date()),
            onYearChange: { _ in }
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


