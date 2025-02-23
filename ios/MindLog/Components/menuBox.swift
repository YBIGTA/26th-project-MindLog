import SwiftUI


struct MenuBox: View {
    let title: String
    let imageName: String
    let textColor: Color
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                // 이미지를 먼저 배치
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width / 2 - 20,
                           height: UIScreen.main.bounds.width / 2 - 20)
                    .clipped()
                
                // 어두운 그라디언트 오버레이 추가
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.5),  // 위쪽 더 어둡게
                        Color.black.opacity(0.2)   // 아래쪽 덜 어둡게
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // 텍스트를 가장 위에 배치
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                    .padding(.leading, 18)
                    .padding(.top, 24)
            }
            .frame(width: UIScreen.main.bounds.width / 2 - 20,
                   height: UIScreen.main.bounds.width / 2 - 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        }
    }
}

// 미리보기
struct MenuBox_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                MenuBox(title: "Feeling",
                       imageName: "calendarImage",
                       textColor: Color(hex: "#FF6B6B"),
                       backgroundColor: Color(hex: "#FFF5F5")) {
                    print("Feeling 클릭됨")
                }
                MenuBox(title: "Place",
                       imageName: "recentImage",
                       textColor: Color(hex: "#4ECDC4"),
                       backgroundColor: Color(hex: "#F2FBFA")) {
                    print("Place 클릭됨")
                }
            }
            HStack(spacing: 12) {
                MenuBox(title: "Companion",
                       imageName: "chartImage",
                       textColor: Color(hex: "#45B7D1"),
                       backgroundColor: Color(hex: "#F5FBFD")) {
                    print("Companion 클릭됨")
                }
                MenuBox(title: "Highlights",
                       imageName: "chartImage",
                       textColor: Color(hex: "#96CEB4"),
                       backgroundColor: Color(hex: "#F7FAF9")) {
                    print("Highlights 클릭됨")
                }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
