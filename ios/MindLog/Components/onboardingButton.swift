import SwiftUI

struct OnboardingButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium)) // SF Pro Display, Medium, 16
                .foregroundColor(Color(uiColor: .systemBackground)) // 글씨 색상 (배경과 반대)
                .frame(height: 46) // 높이 고정
                .frame(maxWidth: .infinity) // 최대 가로 (좌우 최소 안전여백만 남김)
                .background(Color.primary) // 배경색 (라이트: 검정, 다크: 흰색)
                .cornerRadius(120) // 약간 둥근 모서리
        }
        .padding(.horizontal, 12) // 좌우 안전 여백 유지
    }
}

// 미리보기
struct OnboardingButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingButton(title: "Get Started") {}
                .padding()
                .preferredColorScheme(.light) // 라이트 모드

            OnboardingButton(title: "Get Started") {}
                .padding()
                .preferredColorScheme(.dark) // 다크 모드
        }
    }
}
