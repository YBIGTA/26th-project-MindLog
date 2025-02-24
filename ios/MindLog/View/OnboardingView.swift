import SwiftUI

// ✅ Onboarding View (회원가입 & 로그인 선택 포함)
struct OnboardingView: View {
    @State private var currentView: OnboardingStep = .start
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: UIScreen.main.bounds.height * 
                    (currentView == .signUp || currentView == .signIn ? 1/6 : 2/5))
            LogoTitle(size: .big)
                .frame(maxWidth: .infinity)
            Spacer()
            
            Group {
                switch currentView {
                case .start:
                    VStack {
                        OnboardingButton(title: "Get Started") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .authSelection
                            }
                        }
                        .padding(.bottom, 10)
                        
                        Text("By tapping 'Get Started' you agree and consent to our\nTerms of Service and Privacy Policy.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    
                case .authSelection:
                    AuthSelectionView(currentView: $currentView)
                        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    
                case .signUp:
                    SignUpView(currentView: $currentView, keyboardHeight: $keyboardHeight)
                        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                    
                case .signIn:
                    SignInView(currentView: $currentView, keyboardHeight: $keyboardHeight)
                        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// ✅ 단계별 Onboarding Enum
enum OnboardingStep {
    case start, authSelection, signUp, signIn
}

// ✅ 회원가입 / 로그인 선택 화면
struct AuthSelectionView: View {
    @Binding var currentView: OnboardingStep
    
    var body: some View {
        VStack {
            Spacer()
            OnboardingButton(title: "Sign up with E-mail") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentView = .signUp
                }
            }
            OnboardingButton(title: "Sign in") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentView = .signIn
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

// ✅ 회원가입 화면
struct SignUpView: View {
    @Binding var currentView: OnboardingStep
    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var showAlert = false
    @State private var showSuccess = false
    @State private var isLoading = false
    @Binding var keyboardHeight: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 32) {
                InputTextField(type: .username, placeholder: "Username", text: $username)
                InputTextField(type: .email, placeholder: "E-mail", text: $email)
                InputTextField(type: .password, placeholder: "Password", text: $password)
            }
            .padding(.horizontal, 30)
            Spacer()
            OnboardingButton(title: isLoading ? "" : "Sign up") {
                signUp()
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                }
            )
            .disabled(isLoading)
            .padding(.bottom, 8)
            
            Text("Already have an account? Sign in.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .signIn
                    }
                }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height / 2
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
        .alert("회원가입 성공", isPresented: $showSuccess) {
            Button("확인") {
                currentView = .signIn
            }
        } message: {
            Text(authService.successMessage ?? "회원가입이 완료되었습니다.")
        }
        .alert("회원가입 오류", isPresented: $showAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(authService.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
        }
    }
    
    private func signUp() {
        // 입력값 유효성 검사
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            authService.errorMessage = "모든 필드를 입력해주세요."
            showAlert = true
            return
        }
        
        // 이메일 형식 검사
        guard email.contains("@") && email.contains(".") else {
            authService.errorMessage = "올바른 이메일 형식이 아닙니다."
            showAlert = true
            return
        }
        
        // 비밀번호 길이 검사
        guard password.count >= 6 else {
            authService.errorMessage = "비밀번호는 최소 6자 이상이어야 합니다."
            showAlert = true
            return
        }
        
        isLoading = true
        Task {
            do {
                let response = try await authService.register(
                    email: email,
                    password: password,
                    username: username
                )
                await MainActor.run {
                    isLoading = false
                    authService.successMessage = "회원가입이 완료되었습니다."
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    authService.errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct SignInView: View {
    @Binding var currentView: OnboardingStep
    @EnvironmentObject private var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var isLoading = false
    @Binding var keyboardHeight: CGFloat
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                InputTextField(type: .email, placeholder: "E-mail", text: $email)
                InputTextField(type: .password, placeholder: "Password", text: $password)
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            OnboardingButton(title: isLoading ? "" : "Sign in") {
                signIn()
            }
            .padding(.bottom, 8)
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                }
            )
            .disabled(isLoading)
            
            Text("Don't have an account? Sign up.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentView = .signUp
                    }
                }
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                keyboardHeight = keyboardFrame.height / 2
            }
            
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                keyboardHeight = 0
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("로그인 오류"),
                message: Text(authService.errorMessage ?? "알 수 없는 오류가 발생했습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    private func signIn() {
        // 입력값 유효성 검사
        guard !email.isEmpty, !password.isEmpty else {
            authService.errorMessage = "이메일과 비밀번호를 입력해주세요."
            showAlert = true
            return
        }
        
        // 이메일 형식 검사는 AuthService로 위임
        isLoading = true
        Task {
            do {
                // 로그인 시도
                let response = try await authService.login(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                    // 로그인 성공 후 사용자 정보 가져오기
                    Task {
                        do {
                            try await authService.getCurrentUser(token: response.access_token)
                        } catch {
                            authService.errorMessage = "사용자 정보를 가져오는데 실패했습니다."
                            showAlert = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    authService.errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

// ✅ 커스텀 라벨이 있는 텍스트 필드
struct CustomLabeledTextField: View {
    var label: String
    @Binding var text: String
    var isSecure: Bool = false
    var autocapitalization: UITextAutocapitalizationType = .sentences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .foregroundColor(.white)
                .font(.caption)
            if isSecure {
                SecureField("", text: $text)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .autocapitalization(autocapitalization)
            } else {
                TextField("", text: $text)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .autocapitalization(autocapitalization)
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white)
        }
    }
}

// ✅ Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthService())  // AuthService를 환경 객체로 제공
    }
}
