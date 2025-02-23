import SwiftUI

// 📌 태그 크기 타입
enum TagSize {
    case small, big
}

// 📌 기본 태그 뷰 (가로 길이 80 초과 시 '...' 처리)
struct TagView: View {
    let text: String
    let iconName: String
    let size: TagSize

    var body: some View {
        HStack(spacing: 4) { // ✅ 아이콘과 텍스트 사이 여백 4 적용
            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 10, height: 10) // ✅ 아이콘 크기 10 고정
                .foregroundColor(size == .big ? .black : .white) // ✅ 큰 태그: 검정색, 작은 태그: 흰색
            
            Text(text)
                .font(.system(size: 11)) // ✅ 내부 텍스트 크기 11 고정
                .lineLimit(1) // ✅ 한 줄 유지
                .truncationMode(.tail) // ✅ 초과 시 '...'으로 표시
                .frame(maxWidth: 80, alignment: .leading) // ✅ 80px 초과 시 '...' 적용
                .fixedSize(horizontal: true, vertical: false) // ✅ 자동 줄바꿈 방지
                .foregroundColor(size == .big ? .black : .white) // ✅ 큰 태그: 검정색, 작은 태그: 흰색
        }
        .padding(.horizontal, 6) // ✅ 수평 패딩 6 적용
        .frame(height: size == .big ? 24 : 22) // ✅ 큰 태그 높이 24, 작은 태그 높이 22
        .background(
            size == .big
            ? Color.white // ✅ 큰 태그 배경색 #FFFFFF (100%)
            : Color(hex: "#898989").opacity(0.6) // ✅ 작은 태그 배경색 #898989 (60%)
        )
        .cornerRadius(10) // ✅ 코너 스무딩 10 고정
    }
}

struct DateTag: View {
    let date: String
    let size: TagSize
    
    var body: some View {
        TagView(text: date, iconName: "clock.fill", size: size)
    }
}

// 📌 PersonTag (사용자 ID 태그)
struct PersonTag: View {
    let personID: String
    let size: TagSize

    var body: some View {
        TagView(text: personID, iconName: "person.fill", size: size)
    }
}

// 📌 LocationTag (위치 태그)
struct LocationTag: View {
    let locationName: String
    let size: TagSize

    var body: some View {
        TagView(text: locationName, iconName: "location.fill", size: size)
    }
}

// 📌 PlaceTag (장소 태그)
struct PlaceTag: View {
    let placeName: String
    let size: TagSize

    var body: some View {
        TagView(text: placeName, iconName: "map.fill", size: size)
    }
}

// 📌 EmotionTag (감정 태그)
struct EmotionTag: View {
    let emotion: String
    let size: TagSize

    var body: some View {
        TagView(text: emotion, iconName: "face.smiling", size: size)
    }
}

// ✅ 미리보기
struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            HStack {
                DateTag(date: "오후", size: .small)
                PersonTag(personID: "임재민", size: .small)
                LocationTag(locationName: "진짜 장소", size: .small)
                PlaceTag(placeName: "카페", size: .small)
                EmotionTag(emotion: "행복", size: .small)
            }
            HStack {
                DateTag(date: "새벽", size: .big)
                PersonTag(personID: "김민지", size: .big)
                LocationTag(locationName: "강남역 스타벅스 2층 창가 자리", size: .big) // ✅ 가로 길이 80 초과 시 '...'
                PlaceTag(placeName: "스타벅스", size: .big)
                EmotionTag(emotion: "설렘과 기대감이 가득 찬 기분", size: .big) // ✅ 가로 길이 80 초과 시 '...'
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
