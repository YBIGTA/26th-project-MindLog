import SwiftUI

// 카드 크기 타입
enum CardSize {
    case small, medium, large
}

struct ArchiveCardView: View {
    let backgroundImage: String // URL string으로 사용
    let filterImage: String
    let date: String
    let location: String?
    let place: String?
    let people: [String]
    let size: CardSize
    let action: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 📌 배경 이미지 (URL에서 비동기 로드)
            AsyncImage(url: URL(string: backgroundImage)) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .cornerRadius(28)
            } placeholder: {
                Color.gray // 로딩 중 표시할 플레이스홀더
                    .frame(width: cardWidth, height: cardHeight)
                    .cornerRadius(28)
            }
            .overlay(
                Image(filterImage) // 유리 효과 필터는 로컬 이미지
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .cornerRadius(28)
                    .opacity(0.99)
            )
            
            VStack(alignment: .leading) {
                // 📅 날짜 (태그 아님)
                if size == .small {
                    Text(date)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.leading, 21)
                        .padding(.top, 18)
                        
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if let location = location {
                            LocationTag(locationName: location, size: .small)
                        }
                        if let place = place {
                            PlaceTag(placeName: place, size: .small)
                        }
                        ForEach(people.prefix(2), id: \.self) { person in
                            PersonTag(personID: person, size: .small)
                        }
                    }
                    .padding(.leading, 21)
                    .padding(.bottom, 15)
                }
                
              
                if size == .medium {
                    VStack(alignment: .leading) {
                        Spacer()
                        Text(date)
                            .padding(.leading, 31)
                        Spacer()
                            .frame(height: 8)
                        Text("Reprehenderit deserunt sunt adipiscing, amet sit.")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.leading, 31)
                            .padding(.bottom, 30)
                    }
                }
                
                if size == .large {
                    VStack(alignment: .leading) {
                        Spacer()
                        Text(date)
                        Spacer().frame(height: 12)
                        HStack(spacing: 4) {
                            if let location = location {
                                LocationTag(locationName: location, size: .small)
                            }
                            if let place = place {
                                PlaceTag(placeName: place, size: .small)
                            }
                            
                            }
                        Spacer().frame(height: 3)
                        HStack(spacing: 4){
                            ForEach(people, id: \ .self) { person in
                                PersonTag(personID: person, size: .small)
                            }
                        }
                                                    
                    }
                    .padding(.bottom, 25)
                    .padding(.leading, 25)
                    .padding(.trailing, 25)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .contentShape(Rectangle()) // 전체 영역을 탭 가능하게 만듦
    }
    
    // 📌 카드 크기 설정
    private var cardWidth: CGFloat {
        switch size {
        case .small: return UIScreen.main.bounds.width - 40
        case .medium: return 224
        case .large: return UIScreen.main.bounds.width - 40
        }
    }
    
    private var cardHeight: CGFloat {
        switch size {
        case .small: return 128
        case .medium: return 364
        case .large: return 578
        }
    }
}

//// ✅ 미리보기
//struct ArchiveCardView_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 20) {
//            ArchiveCardView(
//                backgroundImage: "preview",
//                filterImage: "glassFilter",
//                date: "Feb 10, 2025",
//                location: "강남역",
//                place: "스타벅스",
//                people: ["김민지", "박지훈"],
//                size: .small,
//                action: { print("Small Card Clicked") }
//            )
//            
//            ArchiveCardView(
//                backgroundImage: "preview",
//                filterImage: "",
//                date: "Feb 10, 2025",
//                location: nil,
//                place: nil,
//                people: [],
//                size: .medium,
//                action: { print("Medium Card Clicked") }
//            )
//            
//            ArchiveCardView(
//                backgroundImage: "preview",
//                filterImage: "glassFilter",
//                date: "Feb 10, 2025",
//                location: "강남역",
//                place: "스타벅스",
//                people: ["김민지", "박지훈", "이서연"],
//                size: .large,
//                action: { print("Large Card Clicked") }
//            )
//        }
//        .padding()
//        .previewLayout(.sizeThatFits)
//    }
//}

import SwiftUI

struct LogOnMap: View {
    let latitude: Double
    let longitude: Double
    let image: String
    let action: () -> Void // 클릭 시 실행할 동작 추가

    var body: some View {
        Button(action: action) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64) // ✅ 크기 명확히 지정
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray, lineWidth: 2) // ✅ Stroke 추가
                )
                .shadow(radius: 5)
        }
        .offset(y: -32) // ✅ 지도 마커보다 위로 이동시킴
    }
}

// ✅ 미리보기
struct LogOnMap_Previews: PreviewProvider {
    static var previews: some View {
        LogOnMap(latitude: 37.5665, longitude: 126.9780, image: "preview") {
            print("Log tapped!")
        }
        .previewLayout(.sizeThatFits)
    }
}
