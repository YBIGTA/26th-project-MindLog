import Foundation
import UIKit

struct DiaryRequest: Encodable {
    let date: String
    let image_urls: [String]
    let emotions: [String]
    let text: String
}

struct TagResponse: Codable {
    let id: String
    let type: String
    let tag_name: String
}

struct DiaryResponse: Codable {
    let id: String
    let date: String
    let image_urls: [String]
    let emotions: [String]
    let text: String?
    let tags: [TagResponse]
    let created_at: String
}

class DiaryService {
    static let shared = DiaryService()
    let baseURL = "http://192.168.0.5:8000"
    
    func createDiary(date: Date, images: [UIImage], emotions: [String], text: String) async throws -> DiaryResponse {
        print("📍 DiaryService - createDiary 함수 시작")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        guard let url = URL(string: "\(baseURL)/diary/") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 600  // 60초로 증가
        
        // JWT 토큰을 Authorization 헤더에 추가
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        let boundary = UUID().uuidString
        print("✅ Boundary 생성:", boundary)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // 날짜 데이터 추가
        let dateString = dateFormatter.string(from: date)
        data.append(createFormField(named: "date", value: dateString, boundary: boundary))
        print("✅ 날짜 데이터 추가:", dateString)
        
        // 감정 데이터 추가 (배열로 전송)
        for emotion in emotions {
            data.append(createFormField(named: "emotions", value: emotion, boundary: boundary))
        }
        print("✅ 감정 데이터 추가:", emotions)
        
        // 텍스트 데이터 추가
        data.append(createFormField(named: "text", value: text, boundary: boundary))
        print("✅ 텍스트 데이터 추가:", text)
        
        // 이미지 데이터 추가
        for (index, image) in images.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                data.append(createFileData(
                    fieldName: "images",
                    fileName: "image\(index).jpg",
                    mimeType: "image/jpeg",
                    fileData: imageData,
                    boundary: boundary
                ))
                print("✅ 이미지 \(index) 추가 완료")
            }
        }
        
        // 마지막 경계선 추가
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        urlRequest.httpBody = data
        print("📡 요청 전송 시작")
        print("- Headers:", urlRequest.allHTTPHeaderFields ?? [:])
        print("- Body size:", data.count, "bytes")
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
            print("✅ 서버로부터 응답 받음")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("- Status code:", httpResponse.statusCode)
                print("- Response headers:", httpResponse.allHeaderFields)
            }
            
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("- Response body:", responseString)
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 201 else {
                print("❌ 잘못된 응답 코드")
                throw URLError(.badServerResponse)
            }
            
            let diaryResponse = try JSONDecoder().decode(DiaryResponse.self, from: responseData)
            print("✅ 응답 디코딩 완료")
            return diaryResponse
            
        } catch {
            print("❌ 네트워크 요청 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
    
    private func createFormField(named name: String, value: String, boundary: String) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        fieldData.append("\(value)\r\n".data(using: .utf8)!)
        return fieldData
    }
    
    private func createFileData(fieldName: String, fileName: String, mimeType: String, fileData: Data, boundary: String) -> Data {
        var data = Data()
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
        return data
    }
    
    func getDiaries() async throws -> [DiaryResponse] {
        print("📍 DiaryService - getDiaries 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/diary/") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        // JWT 토큰을 Authorization 헤더에 추가
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
            print("✅ 서버로부터 응답 받음")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("- Status code:", httpResponse.statusCode)
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ 잘못된 응답 코드:", httpResponse.statusCode)
                    throw URLError(.badServerResponse)
                }
            }
            
            let diaryResponses = try JSONDecoder().decode([DiaryResponse].self, from: responseData)
            print("✅ 응답 디코딩 완료 - \(diaryResponses.count)개의 다이어리")
            return diaryResponses
            
        } catch {
            print("❌ 네트워크 요청 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
    
    func getDiary(id: String) async throws -> DiaryResponse {
        print("📍 DiaryService - getDiary 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/diary/\(id)") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
            print("✅ 서버로부터 응답 받음")
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ 잘못된 응답 코드")
                throw URLError(.badServerResponse)
            }
            
            let diaryResponse = try JSONDecoder().decode(DiaryResponse.self, from: responseData)
            print("✅ 응답 디코딩 완료")
            return diaryResponse
            
        } catch {
            print("❌ 네트워크 요청 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
} 
