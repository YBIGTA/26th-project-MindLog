import SwiftUI

struct Companion: View {
    let image: String  // URL 문자열
    let name: String?
    let action: () -> Void  // ✅ 클릭 이벤트 추가
    @State private var height: CGFloat? = nil  // 높이를 State로 관리
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Button(action: action) {
                GeometryReader { geometry in
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: image)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image("preview")
                                    .resizable()
                                    .scaledToFill()
                            @unknown default:
                                Image("preview")
                                    .resizable()
                                    .scaledToFill()
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width / 2 - 24, height: height ?? 240)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        
                        Text(name ?? "Name")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                }
                .frame(height: height ?? 240)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // onAppear에서 한 번만 높이 설정
            if height == nil {
                height = CGFloat.random(in: 120...360)
            }
            print("🔍 이미지 URL 확인:", image)
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
