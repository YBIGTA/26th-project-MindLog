import SwiftUI
import MapKit

// 📌 로그 데이터 모델 (Identifiable 추가)
struct LogItem: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let image: String
    let category: String  // ✅ 카테고리 추가
}

struct ArchiveMapView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5), // 대한민국 중심 좌표
        span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
    )

    // 📌 대한민국 주요 지역의 예제 로그 데이터 (카테고리 추가됨)
    let logs: [LogItem] = [
        // 도시
        LogItem(latitude: 37.5700, longitude: 126.9760, image: "preview", category: "도시"),  // 광화문
        LogItem(latitude: 37.5600, longitude: 126.9820, image: "preview", category: "도시"),  // 명동
        LogItem(latitude: 37.2636, longitude: 127.0286, image: "preview", category: "도시"),  // 수원 화성
        LogItem(latitude: 35.1595, longitude: 126.8526, image: "preview", category: "도시"),  // 광주 국립아시아문화전당

        // 강가
        LogItem(latitude: 35.8895, longitude: 128.6100, image: "preview", category: "강가"),  // 대구 수성못
        LogItem(latitude: 37.8854, longitude: 127.7298, image: "preview", category: "강가"),  // 춘천 남이섬
        LogItem(latitude: 35.1576, longitude: 129.1183, image: "preview", category: "강가"),  // 해운대 해수욕장

        // 산
        LogItem(latitude: 38.2070, longitude: 128.5918, image: "preview", category: "산"),  // 속초 설악산
        LogItem(latitude: 37.5510, longitude: 126.9880, image: "preview", category: "산"),  // 남산타워

        // 해변
        LogItem(latitude: 33.4996, longitude: 126.5312, image: "preview", category: "해변"),  // 제주 성산일출봉
        LogItem(latitude: 33.2476, longitude: 126.5600, image: "preview", category: "해변"),  // 중문 관광단지
        LogItem(latitude: 35.1028, longitude: 129.0403, image: "preview", category: "해변"),  // 감천문화마을

        // 전통
        LogItem(latitude: 37.5770, longitude: 126.9860, image: "preview", category: "전통"),  // 북촌 한옥마을
        LogItem(latitude: 35.8280, longitude: 127.1475, image: "preview", category: "전통")   // 전주 한옥마을
    ]

    // 📌 카테고리 목록 (타이틀, 부제목)
    let categories: [(String, String)] = [
        ("도시", "4개의 로그"),
        ("강가", "3개의 로그"),
        ("산", "2개의 로그"),
        ("해변", "3개의 로그"),
        ("전통", "2개의 로그")
    ]

    // ✅ 선택된 카테고리에 따라 필터링된 로그 반환
    var filteredLogs: [LogItem] {
        if let selectedCategory = selectedCategory {
            return logs.filter { $0.category == selectedCategory }
        }
        return logs
    }

    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: filteredLogs) { log in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude)) {
                    LogOnMap(latitude: log.latitude, longitude: log.longitude, image: log.image) {
                        print("Log tapped at \(log.latitude), \(log.longitude)")
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                Heading(title: "Place", buttonIcon: nil, menuItems: [])
                
                Spacer()
                
                // 처음 4개의 카테고리만 표시
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(Array(categories.prefix(4)), id: \.0) { category in
                        ExpandableCategoryButton(
                            category: category,
                            onCategorySelected: { selected in
                                selectedCategory = (selectedCategory == selected) ? nil : selected
                            },
                            isSelected: selectedCategory == category.0
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 60)
            }
            
            VStack {
                Spacer()
                FloatingButtonContainer(buttons: [
                    FloatingButton(icon: "arrow.left", text: nil, action: {
                        dismiss()
                    })
                ])
                .padding(.bottom, 6)
            }
        }
        .commonBackground()
    }
}

// ✅ 미리보기
struct ArchiveMapView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveMapView()
    }
}
