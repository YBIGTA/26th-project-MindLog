import SwiftUI

struct DiaryActivity: Decodable {
    let date: String      // "YYYY-MM-DD" 형식
    let hasDiary: Bool
    let emotion: String?
    
    // Date 타입으로 변환하는 계산 프로퍼티
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
    
    private enum CodingKeys: String, CodingKey {
        case date
        case hasDiary = "has_diary"
        case emotion
    }
}

struct HeatmapBox: View {
    let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
    let labelColor: Color = Color(hex: "#B9B9B9")
    let action: () -> Void
    
    // API 응답 데이터를 저장할 프로퍼티
    let activities: [DiaryActivity]
    
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

    private func colorForEmotion(_ emotion: String?) -> Color {
        guard let emotion = emotion else { return Color.gray.opacity(0.4) }
        
        let opacity: Double = 0.7 // 70% 투명도
        
        switch emotion {
        case "기쁨":
            return Color(hex: "#FFD700").opacity(opacity)
        case "신뢰":
            return Color(hex: "#4A90E2").opacity(opacity)
        case "긴장":
            return Color(hex: "#4A4A4A").opacity(opacity)
        case "놀람":
            return Color(hex: "#FF9F1C").opacity(opacity)
        case "슬픔":
            return Color(hex: "#5C85D6").opacity(opacity)
        case "혐오":
            return Color(hex: "#6B8E23").opacity(opacity)
        case "격노":
            return Color(hex: "#E63946").opacity(opacity)
        case "열망":
            return Color(hex: "#9B59B6").opacity(opacity)
        default:
            return Color.gray.opacity(0.4)
        }
    }
    
    func colorForCell(week: Int, day: Int) -> Color {
        let calendar = Calendar.current
        let today = Date()
        
        let weeksAgo = 6 - week
        let daysToSubtract = (weeksAgo * 7) + (todayIndex - day)
        if let cellDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) {
            if cellDate > today {
                return Color(hex: "272727") // 회색 opacity 0.7을 hex 값으로 변경
            }
            
            if let activity = activities.first(where: { 
                guard let activityDate = $0.dateValue else { return false }
                return calendar.isDate(activityDate, inSameDayAs: cellDate) 
            }) {
                if activity.hasDiary {
                    return colorForEmotion(activity.emotion)
                }
            }
            return Color.gray.opacity(0.4)
        }
        return Color.gray.opacity(0.4)
    }
}

struct HeatmapBox_Previews: PreviewProvider {
    static var previews: some View {
        // 테스트용 더미 데이터
        let dummyActivities = [
            DiaryActivity(date: "2025-02-24", hasDiary: true, emotion: "기쁨"),
            DiaryActivity(date: "2025-02-23", hasDiary: false, emotion: nil),
            DiaryActivity(date: "2025-02-22", hasDiary: true, emotion: "슬픔")
        ]
        
        HeatmapBox(action: { print("Button tapped") }, activities: dummyActivities)
            .previewLayout(.sizeThatFits)
    }
}
