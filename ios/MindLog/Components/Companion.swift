import SwiftUI

struct Companion: View {
    let image: String
    let name: String?
    let action: () -> Void  // ✅ 클릭 이벤트 추가
    private let randomHeight: CGFloat = CGFloat.random(in: 120...360)  // 랜덤 높이 추가
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Button(action: action) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        Image(image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width / 2 - 24, height: randomHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        Text(name ?? "Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                }
                .frame(height: randomHeight)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// ✅ 미리보기
struct Companion_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            Companion(image: "preview", name: "대연") {
                print("대연 클릭됨!")
            }
            Companion(image: "preview", name: nil) {
                print("비활성화된 사용자 클릭됨!")
            }
        }
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
