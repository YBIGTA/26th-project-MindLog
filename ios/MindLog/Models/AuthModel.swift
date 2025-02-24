import Foundation

// MARK: - Request Models
struct RegisterRequest: Codable {
    let email: String
    let password: String
    let username: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

// MARK: - Response Models
struct RegisterResponse: Codable {
    let message: String
    let user_id: String
}

struct LoginResponse: Codable {
    let access_token: String
    let token_type: String
    
    var isBearer: Bool {
        return token_type.lowercased() == "bearer"
    }
}

struct UserResponse: Codable {
    let user_id: String
    let email: String
    let username: String
    let created_at: String
    
    var createdDate: Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: created_at)
    }
}