import SwiftUI

struct HeatmapBox: View {
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
    let labelColor: Color = Color(hex: "#B9B9B9")
    let action: () -> Void  // 버튼 액션을 위한 클로저 추가

    var body: some View {
        ZStack {
            // 📌 회색 배경 박스 (가로 최대, 높이 192)
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray6))
                .frame(maxWidth: .infinity)
                .frame(height: 192)// 🔹 가로 최대 확장 설정
            
            // 📌 히트맵과 요일 배치 (모두 박스 내부로 이동)
            HStack(alignment: .center, spacing: 12) {
                // 📅 요일 레이블 열 (세로 정렬)
                VStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { day in
                        Text(days[day])
                            .font(.caption)
                            .foregroundColor(labelColor)
                            .frame(width: 30, height: 15, alignment: .trailing)
                    }
                }
                
                // 🔲 히트맵 그리드: 열은 주(총 7주), 행은 요일
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { week in
                        VStack(spacing: 6) {
                            ForEach(0..<7, id: \.self) { day in
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(colorForCell(week: week, day: day))
                                    .frame(width: 15, height: 15)
                            }
                        }
                    }
                }
                
                Spacer()

                // 📌 👏 클랩 이미지 + ➡️ 원형 버튼 추가 (우측 정렬 적용)
                VStack {
                    Spacer()
                    
                    // ➡️ 원형 버튼 (우측 정렬)
                    HStack {
                        Spacer()
                        Button(action: action) {  // 외부에서 전달받은 action 사용
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white))
                        }
                    }
                }
                .frame(height: 140) // 🔹 클랩 이미지 + 버튼을 한 줄로 정렬
            }
            .padding(24) // 내부 요소 간 여백 추가
        }
        .frame(maxWidth: .infinity) // 🔹 중앙 정렬 유지
    }

    func colorForCell(week: Int, day: Int) -> Color {
        if week < 6 {
            return Color.green
        } else {
            if day < todayIndex {
                return Color.green
            } else if day == todayIndex {
                return Color.blue
            } else {
                return Color.gray.opacity(0.4)
            }
        }
    }
}

struct HeatmapBox_Previews: PreviewProvider {
    static var previews: some View {
        HeatmapBox(action: { print("Button tapped") })
            .previewLayout(.sizeThatFits)
    }
}
