import SwiftUI

struct OnboardingButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium)) // SF Pro Display, Medium, 16
                .foregroundColor(.black) // 글자 색상을 검정으로 고정
                .frame(height: 46) // 높이 고정
                .frame(maxWidth: .infinity) // 최대 가로 (좌우 최소 안전여백만 남김)
                .background(Color.white) // 배경색을 흰색으로 고정
                .cornerRadius(120) // 약간 둥근 모서리
        }
        .padding(.horizontal, 12) // 좌우 안전 여백 유지
    }
}

// 미리보기
struct OnboardingButton_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingButton(title: "Get Started") {}
            .padding()
            .background(Color.black) // 미리보기 배경을 검정으로 설정
    }
}
