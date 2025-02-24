import SwiftUI

struct InputTextField: View {
    enum FieldType {
        case username, email, password
    }
    
    let type: FieldType
    let placeholder: String
    @Binding var text: String
    @State private var isSecure: Bool = true // 비밀번호 가리기 여부
    
    // 색상 설정
    let placeholderColor: Color = Color(hex: "#898989") // 플레이스홀더 색상 (회색)
    let textColor: Color = Color(hex: "#FFFFFF") // 입력 텍스트 색상 (검은색)
    let underlineColor: Color = Color(hex: "#FFFFFF") // 언더라인 색상 (연한 회색)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if type == .password {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .font(.system(size: 12))
                            .foregroundColor(textColor) // 입력 텍스트 색상 적용
                            .padding(.leading, 5)
                    } else {
                        TextField(placeholder, text: $text)
                            .font(.system(size: 12))
                            .foregroundColor(textColor) // 입력 텍스트 색상 적용
                            .padding(.leading, 5)
                    }
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 12))
                        .foregroundColor(textColor) // 입력 텍스트 색상 적용
                        .keyboardType(type == .email ? .emailAddress : .default)
                        .autocapitalization(type == .email ? .none : .words)
                        .disableAutocorrection(true)
                        .padding(.leading, 5)
                }
            }
            
            // 아래 직선 (언더라인)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(underlineColor) // 언더라인 색상 적용
        }
        .frame(minWidth: 100) // 최소한의 가로 길이 유지
        .padding(.horizontal, 12) // 안전 마진 없음
    }
}


// 미리보기
struct InputTextField_Previews: PreviewProvider {
    static var previews: some View {
        @State var username: String = ""
        @State var email: String = ""
        @State var password: String = ""

        VStack(spacing: 20) {
            InputTextField(type: .username, placeholder: "Username", text: $username)
            InputTextField(type: .email, placeholder: "E-mail", text: $email)
            InputTextField(type: .password, placeholder: "Password", text: $password)
        }
        .padding()
    }
}
