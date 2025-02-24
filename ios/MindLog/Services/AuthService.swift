import Foundation
import Security
import SwiftUI

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let baseURL = "http://192.168.0.5:8000"
    private let tokenKey = "com.mindlog.token"
    
    @Published var isAuthenticated = false
    @Published var currentUser: UserResponse?
    @Published var errorMessage: String = ""
    @Published var successMessage: String?
    
    init() {
        // 앱 시작 시 저장된 토큰이 있는지 확인
        if let token = getStoredToken() {
            Task {
                do {
                    // 토큰으로 사용자 정보 가져오기 시도
                    _ = try await getCurrentUser(token: token)
                    await MainActor.run {
                        self.isAuthenticated = true
                    }
                } catch {
                    // 토큰이 만료되었거나 유효하지 않은 경우
                    await MainActor.run {
                        self.isAuthenticated = false
                        deleteStoredToken()
                    }
                }
            }
        }
    }
    
    // MARK: - Token Management
    
    private func storeToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "jwtToken")
        print("✅ 토큰 저장됨:", token)
    }
    
    private func getStoredToken() -> String? {
        return UserDefaults.standard.string(forKey: "jwtToken")
    }
    
    private func deleteStoredToken() {
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        print("🗑️ 토큰 삭제됨")
    }
    
    // MARK: - Auth Methods
    
    func register(email: String, password: String, username: String) async throws -> RegisterResponse {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        guard isValidPassword(password) else { throw AuthError.weakPassword }
        guard isValidUsername(username) else { throw AuthError.invalidUsername }
        
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let registerRequest = RegisterRequest(email: email, password: password, username: username)
        request.httpBody = try JSONEncoder().encode(registerRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
            await MainActor.run {
                self.successMessage = registerResponse.message
            }
            return registerResponse
        case 400:
            throw AuthError.invalidCredentials
        case 409:
            throw AuthError.emailAlreadyExists
        default:
            throw AuthError.serverError
        }
    }
    
    func login(email: String, password: String) async throws -> LoginResponse {
        guard isValidEmail(email) else { throw AuthError.invalidEmail }
        
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "password",
            "username": email,
            "password": password,
            "scope": "",
            "client_id": "string",
            "client_secret": "string"
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        print("📡 로그인 요청 시작")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        print("📡 서버 응답 코드:", httpResponse.statusCode)
        
        switch httpResponse.statusCode {
        case 200...299:
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            if !loginResponse.isBearer {
                throw AuthError.invalidTokenType
            }
            
            await MainActor.run {
                self.isAuthenticated = true
                storeToken(loginResponse.access_token)
            }
            print("✅ 로그인 성공")
            return loginResponse
            
        case 401:
            print("❌ 인증 실패")
            throw AuthError.invalidCredentials
        case 404:
            print("❌ 사용자 없음")
            throw AuthError.userNotFound
        default:
            print("❌ 서버 에러")
            throw AuthError.serverError
        }
    }
    
    func getCurrentUser(token: String) async throws -> UserResponse {
        let url = URL(string: "\(baseURL)/auth/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let userResponse = try JSONDecoder().decode(UserResponse.self, from: data)
            await MainActor.run {
                self.currentUser = userResponse
            }
            return userResponse
        case 401:
            await MainActor.run {
                self.isAuthenticated = false
                deleteStoredToken()
            }
            throw AuthError.invalidCredentials
        default:
            throw AuthError.serverError
        }
    }
    
    func logout() {
        deleteStoredToken()
        isAuthenticated = false
        currentUser = nil
    }
    
    func refreshUserSession() async {
        guard let token = getStoredToken() else {
            isAuthenticated = false
            return
        }
        
        do {
            _ = try await getCurrentUser(token: token)
        } catch {
            isAuthenticated = false
            deleteStoredToken()
        }
    }
    
    // MARK: - Validation Methods
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        let passwordRegex = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d]{6,}$"
        let passwordPredicate = NSPredicate(format:"SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// 커스텀 에러 정의
enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case invalidUsername
    case invalidCredentials
    case emailAlreadyExists
    case networkError
    case serverError
    case userNotFound
    case invalidTokenType
    
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "올바른 이메일 형식이 아닙니다."
        case .weakPassword:
            return "비밀번호는 최소 6자 이상이며, 영문과 숫자를 포함해야 합니다."
        case .invalidUsername:
            return "사용자 이름을 입력해주세요."
        case .invalidCredentials:
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .emailAlreadyExists:
            return "이미 존재하는 이메일입니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        case .serverError:
            return "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
        case .userNotFound:
            return "등록되지 않은 사용자입니다."
        case .invalidTokenType:
            return "유효하지 않은 토큰 타입입니다."
        }
    }
}
