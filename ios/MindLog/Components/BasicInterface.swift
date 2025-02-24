import SwiftUI

struct Heading: View {
    let title: String
    let buttonIcon: String? // 선택적 버튼 아이콘 (SF Symbol)
    let menuItems: [MenuItem] // String 배열에서 MenuItem 배열로 변경
    
    // 대신 이벤트 핸들러 추가
    var onCalendarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let buttonIcon = buttonIcon {
                if buttonIcon == "calendar" {
                    Button(action: {
                        onCalendarTap?()  // 상위 뷰의 핸들러 호출
                    }) {
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Image(systemName: buttonIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // 기본 터치 효과 제거
                } else if buttonIcon == "chevron.down" {
                    Menu {
                        ForEach(menuItems) { item in
                            if item.isDivider {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            } else {
                                Button(action: item.action) {
                                    HStack {
                                        if item.isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                        Text(item.title)
                                        Spacer()
                                        // 각 메뉴 아이템별 아이콘 추가
                                        Image(systemName: getMenuIcon(for: item.title))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Image(systemName: buttonIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                // 📌 버튼이 없을 경우 일반 텍스트
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading) // 좌측 정렬 유지
    }
}
// ✅ 미리보기
//struct Heading_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack(spacing: 20) {
//            // 일반 헤딩 (버튼 없음)
//            Heading(title: "Archive", buttonIcon: nil, menuItems: [])
//            
//            // 드롭다운 메뉴 버튼 포함
//            Heading(title: "MindLog.", buttonIcon: "chevron.down", menuItems: [
//                MenuItem(title: "Settings", isSelected: false, action: {}),
//                MenuItem(title: "Profile", isSelected: false, action: {}),
//                MenuItem(title: "Logout", isSelected: false, action: {})
//            ])
//            
//            // 캘린더 버튼이 있는 경우
//            Heading(title: "Select Date", buttonIcon: "calendar", menuItems: [])
//        }
//        .padding()
//        .previewLayout(.sizeThatFits)
//        .background(Color.black)
//    }
//}

struct FloatingButton: View {
    let icon: String
    let text: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: text != nil ? 8 : 0) { // 아이콘과 텍스트 사이 여백 적용
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)

                if let text = text {
                    Text(text)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.black)
            .padding(.horizontal, text != nil ? 11 : 0) // 아이콘 + 텍스트 있을 경우만 패딩 적용
            .frame(width: text != nil ? nil : 44, height: 44) // 원형 또는 사각형 크기 적용
            .background(
                Group {
                    if text != nil {
                        RoundedRectangle(cornerRadius: 36).fill(Color.white)
                    } else {
                        Circle().fill(Color.white)
                    }
                }
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5) // 쉐도우 적용
        }
    }
}

struct ExpandableCategoryButton: View {
    let category: (String, String)
    let onCategorySelected: (String) -> Void
    let isSelected: Bool
    let backgroundColor: Color

    init(
        category: (String, String),
        onCategorySelected: @escaping (String) -> Void,
        isSelected: Bool,
        backgroundColor: Color = Color(white: 0.2)
    ) {
        self.category = category
        self.onCategorySelected = onCategorySelected
        self.isSelected = isSelected
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if !isSelected {
                    onCategorySelected(category.0)
                }
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.0)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Text(category.1)
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isSelected {
                    Button(action: {
                        print("\(category.0) 상세 보기")
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 42, height: 42)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.gray : backgroundColor)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExpandableCategoryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ExpandableCategoryButton(category: ("도시", "5개의 로그"), onCategorySelected: { _ in }, isSelected: false)
        }
        .padding()
        .foregroundColor(Color(hex: "2c3e50"))
        .previewLayout(.sizeThatFits)
    }
}

// ✅ 사용자가 원하는 만큼 버튼을 넣을 수 있도록 개선
struct FloatingButtonContainer: View {
    let buttons: [FloatingButton]

    var body: some View {
        HStack(spacing: 4) { // ✅ 버튼 간격 조절 가능
            ForEach(0..<buttons.count, id: \.self) { index in
                buttons[index]
            }
        }
        .frame(maxWidth: .infinity)
    }
}
//
//struct basicInterface_Previews: PreviewProvider {
//    static var previews: some View {
//        VStack{
//            Heading(title: "MindLog.", buttonIcon: "chevron.down", menuItems: ["MindLog", "Archive"])
//            Spacer()
//            FloatingButtonContainer(buttons: [
//                FloatingButton(icon: "camera", text: nil, action: { print("카메라 버튼 클릭") }),
//                FloatingButton(icon: "square.and.arrow.up", text: "공유", action: { print("공유 버튼 클릭") }),
//                FloatingButton(icon: "plus", text: "새 기록", action: { print("새 기록 버튼 클릭") })
//            ])
//        }
//    }
//}

// ✅ 미리보기
struct FloatingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            FloatingButtonContainer(buttons: [
                FloatingButton(icon: "camera", text: nil, action: { print("카메라 버튼 클릭") }),
                FloatingButton(icon: "square.and.arrow.up", text: "공유", action: { print("공유 버튼 클릭") }),
                FloatingButton(icon: "plus", text: "새 기록", action: { print("새 기록 버튼 클릭") })
            ])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
    }
}

private func formatMonth(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy'년' M'월'"  // 작은따옴표로 감싸서 리터럴로 처리
    return formatter.string(from: date)
}

struct DiaryTitle: View {
    let title: String
    let buttonIcon: String? // 선택적 버튼 아이콘 (SF Symbol)
    let menuItems: [MenuItem] // String 배열에서 MenuItem 배열로 변경
    
    // 대신 이벤트 핸들러 추가
    var onCalendarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let buttonIcon = buttonIcon {
                if buttonIcon == "calendar" {
                    Button(action: {
                        onCalendarTap?()
                    }) {
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.system(size: 24, weight: .bold))  // 32에서 24로 축소
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Image(systemName: buttonIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)  // 16에서 14로 축소
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } else if buttonIcon == "chevron.down" {
                    Menu {
                        ForEach(menuItems) { item in
                            if item.isDivider {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                            } else {
                                Button(action: item.action) {
                                    HStack {
                                        if item.isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                        Text(item.title)
                                        Spacer()
                                        // 각 메뉴 아이템별 아이콘 추가
                                        Image(systemName: getMenuIcon(for: item.title))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(title)
                                .font(.system(size: 24, weight: .bold))  // 32에서 24로 축소
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Image(systemName: buttonIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)  // 16에서 14로 축소
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                Text(title)
                    .font(.system(size: 24, weight: .bold))  // 32에서 24로 축소
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ✅ 미리보기

private func getMenuIcon(for title: String) -> String {
    switch title {
        case "MindLog.":
            return "photo.on.rectangle.angled"
        case "Archive":
            return "folder"
        case "Logout":
            return "rectangle.portrait.and.arrow.right"
        default:
            return ""
    }
}

