import SwiftUI

struct LogoTitle: View {
    enum LogoSize {
        case big, medium
    }
    
    let size: LogoSize

    var body: some View {
        Text("MindLog.") // 로고 텍스트
            .font(.system(size: size == .big ? 32 : 28, weight: .bold)) // 크기 조절
            .kerning(-0.4) // 글자 간격 조절
            .foregroundColor(.white) // 항상 흰색으로 설정
    }
}

// 미리보기
struct LogoTitle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LogoTitle(size: .big)
            LogoTitle(size: .medium)
        }
        .padding()
        .background(Color.black) // 미리보기 배경을 검정으로 설정
    }
}
