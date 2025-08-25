import Foundation
import UIKit
import UniformTypeIdentifiers

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

struct PlaceDiary: Codable, Identifiable {
    let id: String
    let thumbnail_url: String
    let latitude: Double?
    let longitude: Double?
}

struct PlaceGroup: Codable {
    let category: String
    let diary_count: Int
    let diaries: [PlaceDiary]
}

struct PlaceGroupResponse: Codable {
    let places: [PlaceGroup]
}

struct DiaryGenerationRequest: Codable {
    let emotions: [String]
    let tags: [[String: String]]  // AI 서버 기대 형식에 맞춤
    let user_text: String?
}

struct DiaryGenerationResponse: Codable {
    let generated_text: String
    let status: String
}

class DiaryService {
    static let shared = DiaryService()
    let baseURL = "http://localhost:8000"
    let aiServerURL = "http://localhost:8001"  // AI 서버 URL
    
    func createDiary(date: Date, images: [(image: UIImage, metadata: [String: Any]?)], emotions: [String], text: String) async throws -> DiaryResponse {
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
        urlRequest.timeoutInterval = 600
        
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
        
        // 감정 데이터 추가
        for emotion in emotions {
            data.append(createFormField(named: "emotions", value: emotion, boundary: boundary))
        }
        print("✅ 감정 데이터 추가:", emotions)
        
        // 텍스트 데이터 추가
        data.append(createFormField(named: "text", value: text, boundary: boundary))
        print("✅ 텍스트 데이터 추가:", text)
        
        // 이미지 데이터 추가 (수정된 부분)
        for (index, imageInfo) in images.enumerated() {
            print("\n📍 이미지 \(index) 처리 시작")
            
            if let imageData = imageInfo.image.jpegData(compressionQuality: 0.8) {
                print("2️⃣ JPEG 데이터 생성 완료 (\(imageData.count) bytes)")
                var finalImageData = imageData
                
                // 메타데이터가 있는 경우에만 처리
                if let metadata = imageInfo.metadata {
                    if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
                        let mutableData = NSMutableData(data: imageData)
                        if let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) {
                            // 원본 메타데이터를 그대로 사용
                            CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
                            
                            if CGImageDestinationFinalize(destination) {
                                finalImageData = mutableData as Data
                                print("✅ 메타데이터가 포함된 이미지 생성 완료 (\(finalImageData.count) bytes)")
                            }
                        }
                    }
                }
                
                data.append(createFileData(
                    fieldName: "images",
                    fileName: "image\(index).jpg",
                    mimeType: "image/jpeg",
                    fileData: finalImageData,
                    boundary: boundary
                ))
            }
        }
        
        // 나머지 코드는 그대로 유지
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        urlRequest.httpBody = data
        
        print("📡 요청 전송 시작")
        print("- Headers:", urlRequest.allHTTPHeaderFields ?? [:])
        print("- Body size: \(data.count) bytes")
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 잘못된 응답 형식")
            throw URLError(.badServerResponse)
        }
        
        print("✅ 서버로부터 응답 받음")
        print("- Status code:", httpResponse.statusCode)
        print("- Response headers:", httpResponse.allHeaderFields)
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("- Response body:", responseString)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ 서버 에러 응답")
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let diaryResponse = try decoder.decode(DiaryResponse.self, from: responseData)
        
        print("✅ 응답 디코딩 완료")
        print("✅ 서버 응답 성공:", diaryResponse)
        
        return diaryResponse
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
    
    func getDiariesByPlace() async throws -> PlaceGroupResponse {
        print("📍 DiaryService - getDiariesByPlace 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/diary/place") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        print("✅ URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            print("✅ JWT 토큰:", token)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("❌ JWT 토큰 없음")
            throw URLError(.userAuthenticationRequired)
        }
        
        print("📡 요청 시작")
        print("- Headers:", request.allHTTPHeaderFields ?? [:])
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ HTTP 응답이 아님")
                throw URLError(.badServerResponse)
            }
            
            print("📡 서버 응답 받음")
            print("- Status code:", httpResponse.statusCode)
            print("- Headers:", httpResponse.allHeaderFields)
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("📝 응답 데이터:\n\(responseString)")
            }
            
            print("🔍 JSON 디코딩 시작")
            do {
                let places = try JSONDecoder().decode([PlaceGroup].self, from: data)
                print("✅ JSON 디코딩 성공")
                return PlaceGroupResponse(places: places)
            } catch {
                print("❌ JSON 디코딩 실패")
                print("- 에러:", error)
                print("- 디코딩 에러 상세:", (error as? DecodingError).map { debugDecodingError($0) } ?? "알 수 없는 에러")
                throw error
            }
        } catch {
            print("❌ 네트워크 요청 실패")
            print("- 에러:", error.localizedDescription)
            throw error
        }
    }
    
    // 일기 텍스트 자동 생성 함수
    func generateDiaryText(emotions: [String], tags: [TagResponse], userText: String? = nil) async throws -> String {
        print("📍 DiaryService - generateDiaryText 함수 시작")
        
        guard let url = URL(string: "\(aiServerURL)/ai/generate-diary-text") else {
            print("❌ 잘못된 AI 서버 URL")
            throw URLError(.badURL)
        }
        print("✅ AI 서버 URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // TagResponse를 딕셔너리로 변환
        let tagDicts = tags.map { tag in
            ["type": tag.type, "tag_name": tag.tag_name]
        }
        
        print("📍 DiaryService - 변환된 태그 딕셔너리: \(tagDicts)")
        print("📍 DiaryService - 변환된 태그 딕셔너리 개수: \(tagDicts.count)")
        
        // 요청 데이터 생성
        let requestData = DiaryGenerationRequest(
            emotions: emotions,
            tags: tagDicts,
            user_text: userText
        )
        
        print("📍 DiaryService - 최종 요청 데이터:")
        print("  - emotions: \(emotions)")
        print("  - tags: \(tagDicts)")
        print("  - user_text: \(userText ?? "nil")")
        
        do {
            let jsonData = try JSONEncoder().encode(requestData)
            request.httpBody = jsonData
            
            print("📡 AI 서버로 요청 전송")
            print("- 감정:", emotions)
            print("- 원본 태그:", tags.map { "\($0.type): \($0.tag_name)" })
            print("- 변환된 태그 딕셔너리:", tagDicts)
            print("- 사용자 텍스트:", userText ?? "없음")
            
            // JSON 확인
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("📡 전송할 JSON:", jsonString)
            }
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 잘못된 응답 형식")
                throw URLError(.badServerResponse)
            }
            
            print("✅ AI 서버로부터 응답 받음")
            print("- Status code:", httpResponse.statusCode)
            
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("- Response body:", responseString)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ AI 서버 에러 응답")
                throw URLError(.badServerResponse)
            }
            
            let decoder = JSONDecoder()
            let diaryResponse = try decoder.decode(DiaryGenerationResponse.self, from: responseData)
            
            print("✅ 일기 텍스트 생성 성공:", diaryResponse.generated_text)
            
            return diaryResponse.generated_text
            
        } catch {
            print("❌ 일기 텍스트 생성 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
    
    // 이미지에서 태그 생성 함수 (URL 기반)
    func generateTagsFromImages(imageUrls: [String]) async throws -> [TagResponse] {
        print("📍 DiaryService - generateTagsFromImages 함수 시작")
        
        guard let url = URL(string: "\(aiServerURL)/ai/generate-tags") else {
            print("❌ 잘못된 AI 서버 URL")
            throw URLError(.badURL)
        }
        print("✅ AI 서버 URL 생성됨:", url.absoluteString)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        // 요청 데이터 생성
        let requestData = ["image_urls": imageUrls]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            request.httpBody = jsonData
            
            print("📡 AI 서버로 태그 생성 요청 전송")
            print("- 이미지 URL 개수:", imageUrls.count)
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 잘못된 응답 형식")
                throw URLError(.badServerResponse)
            }
            
            print("✅ AI 서버로부터 응답 받음")
            print("- Status code:", httpResponse.statusCode)
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ AI 서버 에러 응답")
                throw URLError(.badServerResponse)
            }
            
            // Parse response
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                
                var allTags: [TagResponse] = []
                for result in results {
                    if let tags = result["tags"] as? [[String: String]] {
                        for tagDict in tags {
                            if let type = tagDict["type"],
                               let tagName = tagDict["tag_name"] {
                                let tag = TagResponse(id: UUID().uuidString, type: type, tag_name: tagName)
                                allTags.append(tag)
                            }
                        }
                    }
                }
                
                print("✅ 태그 생성 성공:", allTags.map { "\($0.type): \($0.tag_name)" })
                return allTags
            }
            
            return []
            
        } catch {
            print("❌ 태그 생성 실패")
            print("- Error:", error.localizedDescription)
            throw error
        }
    }
    
    // 임시 이미지 업로드 함수
    func uploadTempImages(images: [(image: UIImage, metadata: [String: Any]?)]) async throws -> [String] {
        print("📍 DiaryService - uploadTempImages 함수 시작")
        
        guard let url = URL(string: "\(baseURL)/diary/upload-temp-images") else {
            print("❌ 잘못된 URL")
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 600
        
        if let token = UserDefaults.standard.string(forKey: "jwtToken") {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let boundary = UUID().uuidString
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        
        // 이미지 데이터 추가
        for (index, imageInfo) in images.enumerated() {
            if let imageData = imageInfo.image.jpegData(compressionQuality: 0.8) {
                var finalImageData = imageData
                
                // 메타데이터가 있는 경우 처리
                if let metadata = imageInfo.metadata {
                    if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
                        let mutableData = NSMutableData(data: imageData)
                        if let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) {
                            CGImageDestinationAddImageFromSource(destination, source, 0, metadata as CFDictionary)
                            
                            if CGImageDestinationFinalize(destination) {
                                finalImageData = mutableData as Data
                            }
                        }
                    }
                }
                
                data.append(createFileData(
                    fieldName: "images",
                    fileName: "temp_image\(index).jpg",
                    mimeType: "image/jpeg",
                    fileData: finalImageData,
                    boundary: boundary
                ))
            }
        }
        
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = data
        
        print("📡 임시 이미지 업로드 요청 전송")
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let imageUrls = json["image_urls"] as? [String] {
            print("✅ 임시 이미지 업로드 완료: \(imageUrls.count)개 URL")
            return imageUrls
        }
        
        throw URLError(.cannotParseResponse)
    }
    
    // 이미지 데이터에서 태그 생성 함수 (실제 S3 업로드 후 AI 서버 요청)
    func generateTagsFromImageData(images: [(image: UIImage, metadata: [String: Any]?)]) async throws -> [TagResponse] {
        print("📍 DiaryService - generateTagsFromImageData 함수 시작")
        print("📍 DiaryService - 분석할 이미지 개수: \(images.count)")
        
        // Step 1: Upload images to S3 temporarily
        print("📍 DiaryService - S3 임시 업로드 시작...")
        let imageUrls = try await uploadTempImages(images: images)
        print("📍 DiaryService - S3 업로드 완료, URL 개수: \(imageUrls.count)")
        print("📍 DiaryService - 업로드된 URL들: \(imageUrls)")
        
        // Step 2: Send real URLs to AI server for tagging
        print("📍 DiaryService - AI 서버 태깅 요청 시작...")
        let tags = try await generateTagsFromImages(imageUrls: imageUrls)
        print("📍 DiaryService - AI 서버에서 받은 태그: \(tags.map { "\($0.type): \($0.tag_name)" })")
        
        return tags
    }
    
    // 디코딩 에러 디버깅을 위한 헬퍼 함수
    private func debugDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return "데이터 손상: \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "키를 찾을 수 없음: \(key.stringValue) at path: \(context.codingPath)"
        case .typeMismatch(let type, let context):
            return "타입 불일치: \(type) at path: \(context.codingPath)"
        case .valueNotFound(let type, let context):
            return "값을 찾을 수 없음: \(type) at path: \(context.codingPath)"
        @unknown default:
            return "알 수 없는 디코딩 에러"
        }
    }
} 
