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

struct ImageInfo: Codable {
    let image_url: String
}

struct DiaryResponse: Codable {
    let id: String
    let date: String
    let images: [ImageInfo]
    let emotions: [String]
    let text: String?
    let tags: [TagResponse]
    let created_at: String
}

struct EmotionRatioResponse: Codable {
    let 기쁨: Double
    let 신뢰: Double
    let 긴장: Double
    let 놀람: Double
    let 슬픔: Double
    let 혐오: Double
    let 격노: Double
    let 열망: Double
}

struct DominantEmotionResponse: Codable {
    let emotion: String  // 서버에서 오는 그대로의 키 이름 사용
}

struct MonthlyEmotionResponse: Codable {
    let JAN: Int
    let FEB: Int
    let MAR: Int
    let APR: Int
    let MAY: Int
    let JUN: Int
    let JUL: Int
    let AUG: Int
    let SEP: Int
    let OCT: Int
    let NOV: Int
    let DEC: Int
}

struct PersonGroupResponse: Codable {
    struct Person: Codable {
        let person_name: String
        let thumbnail_url: String
        let diary_count: Int
    }
    
    let people: [Person]
}

struct RecentActivityResponse: Decodable {
    let recentActivity: [DiaryActivity]
    
    private enum CodingKeys: String, CodingKey {
        case recentActivity = "recent_activity"
    }
}

struct PersonDiaryResponse: Codable {
    let person_name: String
    let diaries: [PersonDiary]
    
    struct PersonDiary: Codable {
        let id: String
        let date: String
        let thumbnail_url: String
        let text: String
    }
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
    
    func getFeelingRatio(year: Int) async throws -> EmotionRatioResponse {
        print("📍 DiaryService - getFeelingRatio 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/feeling?year=\(year)") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        
        // JWT 토큰을 Authorization 헤더에 추가
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("✅ 서버로부터 응답 받음")
        print("- Status code:", httpResponse.statusCode)
        
        let decoder = JSONDecoder()
        let emotionRatio = try decoder.decode(EmotionRatioResponse.self, from: data)
        print("✅ 응답 디코딩 완료")
        
        return emotionRatio
    }
    
    func getDominantEmotion(year: Int) async throws -> DominantEmotionResponse {
        guard let url = URL(string: "\(baseURL)/archive/feeling?year=\(year)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // 서버 응답 출력
        if let jsonString = String(data: data, encoding: .utf8) {
            print("서버 응답 JSON:", jsonString)
        }
        
        let response = try JSONDecoder().decode(DominantEmotionResponse.self, from: data)
        return response
    }
    
    func getDiariesByDate(year: Int? = nil, month: Int? = nil) async throws -> [DiaryResponse] {
        print("📍 DiaryService - getDiariesByDate 함수 시작")
        
        var urlComponents = URLComponents(string: "\(baseURL)/diary/")
        var queryItems: [URLQueryItem] = []
        
        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: String(month)))
        }
        
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
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
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTP 응답이 아님")
                throw URLError(.badServerResponse)
            }
            
            print("📡 응답 상태 코드:", httpResponse.statusCode)
            
            // 응답 데이터 출력 (디버깅용)
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("📡 응답 데이터:", responseString)
            }
            
            // 200~299 범위의 상태 코드 허용
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ 잘못된 응답 코드:", httpResponse.statusCode)
                throw URLError(.badServerResponse)
            }
            
            let diaryResponses = try JSONDecoder().decode([DiaryResponse].self, from: responseData)
            print("✅ 응답 디코딩 완료 - \(diaryResponses.count)개의 다이어리")
            return diaryResponses
            
        } catch let decodingError as DecodingError {
            print("❌ 디코딩 에러:", decodingError)
            throw decodingError
        } catch {
            print("❌ 네트워크 요청 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
    
    func getMonthlyEmotionCount(emotion: String, year: Int) async throws -> MonthlyEmotionResponse {
        print("📍 DiaryService - getMonthlyEmotionCount 함수 시작")
        print("- 감정:", emotion)
        print("- 연도:", year)
        
        // URL 인코딩 없이 직접 문자열 연결
        let urlString = "\(baseURL)/feeling/\(emotion)?year=\(year)"
        guard let url = URL(string: urlString) else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ 잘못된 응답 코드")
            throw URLError(.badServerResponse)
        }
        
        print("✅ 서버로부터 응답 받음")
        print("- Status code:", httpResponse.statusCode)
        
        let monthlyData = try JSONDecoder().decode(MonthlyEmotionResponse.self, from: data)
        print("✅ 응답 디코딩 완료")
        
        return monthlyData
    }
    
    func getGroupedByPerson() async throws -> PersonGroupResponse {
        print("📍 DiaryService - getGroupedByPerson 함수 시작")
        
        let urlString = "\(baseURL)/diary/grouped-by-person"
        guard let url = URL(string: urlString) else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ 잘못된 응답 코드")
            if let responseString = String(data: data, encoding: .utf8) {
                print("응답 내용:", responseString)
            }
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(PersonGroupResponse.self, from: data)
        print("✅ 응답 디코딩 완료")
        print("- 동행인 수:", result.people.count)
        return result
    }
    
    func getRecentActivities() async throws -> [DiaryActivity] {
        print("📍 DiaryService - getRecentActivities 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/diary/recent-activity") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰 확인:", token)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        let (data, httpResponse) = try await URLSession.shared.data(for: request)
        
        guard let response = httpResponse as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            print("❌ 잘못된 응답 코드")
            throw URLError(.badServerResponse)
        }
        
        print("✅ 서버로부터 응답 받음")
        print("- Status code:", response.statusCode)
        
        let decoder = JSONDecoder()
        let activityResponse = try decoder.decode(RecentActivityResponse.self, from: data)
        print("✅ 응답 디코딩 완료 - \(activityResponse.recentActivity.count)개의 활동")
        
        return activityResponse.recentActivity
    }
    
    func getDiariesByPerson(name: String) async throws -> PersonDiaryResponse {
        print("📍 DiaryService - getDiariesByPerson 함수 시작")
        
        let urlString = "\(baseURL)/diary/by-person/\(name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: urlString) else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            print("❌ 잘못된 응답 코드")
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(PersonDiaryResponse.self, from: data)
        print("✅ 응답 디코딩 완료")
        return result
    }
} 
