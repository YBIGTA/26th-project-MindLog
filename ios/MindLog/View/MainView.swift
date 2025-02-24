import SwiftUI
import PhotosUI

struct MainView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var diaryEntries: [DiaryEntry] = []
    @State private var isDropdownOpen = false
    @State private var selectedView: MainViewSelection = .main
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var showWriteLogView = false
    @State private var isLoading = false
    @State private var showArchiveView = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // 배경 탭 감지를 위한 투명한 전체 화면 버튼
                if isDropdownOpen {
                    Color.black.opacity(0.01) // 거의 투명한 배경
                        .onTapGesture {
                            withAnimation {
                                isDropdownOpen = false
                            }
                        }
                }
                
                // 메인 콘텐츠
                Group {
                    if selectedView == .main {
                        VStack {
                            // 상단 MindLog 및 드롭다운 버튼
                            HStack {
                                Heading(
                                    title: "MindLog.",
                                    buttonIcon: "chevron.down",
                                    menuItems: [
                                        MenuItem(title: "MindLog.", isSelected: true) {
                                            withAnimation {
                                                selectedView = .main
                                            }
                                        },
                                        MenuItem(title: "Archive", isSelected: false) {
                                            showArchiveView = true
                                        },
                                        MenuItem(title: "", isSelected: false, isDivider: true) {},
                                        MenuItem(title: "Logout", isSelected: false) {
                                            showLogoutAlert = true
                                        }
                                    ]
                                )
                                .padding(.leading, UIScreen.main.bounds.width * 0.01)
                                
                                Spacer()
                                
                                // 새로고침 버튼 추가
                                Button(action: {
                                    Task {
                                        await fetchDiaryEntries()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                }
                                .padding(.trailing, UIScreen.main.bounds.width * 0.04)
                            }
                            .padding(.top, UIScreen.main.bounds.height * 0.02)
                            
                            Spacer()
                            
                            // 다이어리 슬라이드 뷰
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    if diaryEntries.isEmpty {
                                        // 빈 상태 카드
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 15)
                                                .fill(Color(UIColor.systemGray6))
                                                .frame(width: 200, height: 300)
                                            
                                            VStack(spacing: 12) {
                                                Image(systemName: "square.and.pencil")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.gray)
                                                
                                                Text("첫 마인드로그를\n남겨보세요")
                                                    .font(.headline)
                                                    .multilineTextAlignment(.center)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    } else {
                                        ForEach(diaryEntries) { entry in
                                            NavigationLink {
                                                LoadingView(diaryId: entry.id)
                                            } label: {
                                                DiaryCardView(entry: entry)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .overlay {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                }
                            }
                            
                            Spacer()
                            
                            // 날짜 및 사용자 정보
                            VStack(alignment: .leading) {
                                Text(getCurrentDate())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Text("Hello, \(authService.currentUser?.username ?? "User")")
                                    .font(.largeTitle)
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.bottom, 10)
                                Text("하루를 기록하는 작은 습관이,\n내 마음을 더 깊이 이해할 수 있도록 도와줄 거예요.\n기록된 순간들은 나에게 따뜻한 위로가 되어준답니다.\n오늘 하루, 스스로에게 솔직한 한 줄을 남겨보세요.")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .tracking(-0.5)
                            }
                            .padding(.bottom, 40)
                            
                            // Ready to Log 버튼
                            FloatingButton(
                                icon: "pencil",
                                text: "Ready to Log",
                                action: {
                                    showWriteLogView = true
                                }
                            )
                            .padding(.horizontal, 30)
                            .padding(.bottom, 16)
                            .fullScreenCover(isPresented: $showWriteLogView) {
                                WriteLogView()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .commonsecondBackground()
                
                // 드롭다운 메뉴
                if isDropdownOpen {
                    VStack(alignment: .leading, spacing: 5) {
                        Button(action: {
                            withAnimation {
                                selectedView = .main
                                isDropdownOpen = false
                            }
                        }) {
                            HStack {
                                Text("MindLog.")
                                Spacer()
                                Image(systemName: "photo.on.rectangle.angled")
                            }
                            .foregroundColor(.white)
                        }
                        .padding()
                        
                        Divider()
                        
                        Button(action: {}) {
                            HStack {
                                Text("Archive")
                                Spacer()
                                Image(systemName: "folder")
                            }
                            .foregroundColor(.white)
                        }
                        .padding()
                    }
                    .frame(width: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .offset(x: -110, y: 50)
                    .padding(.leading)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await fetchDiaryEntries()
                }
            }
        }
        .fullScreenCover(isPresented: $showArchiveView) {
            ArchiveMainView()
        }
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                authService.logout()
            }
        } message: {
            Text("로그아웃하시겠습니까?")
        }
    }
    
    private func fetchDiaryEntries() async {
        isLoading = true
        
        do {
            let responses = try await DiaryService.shared.getDiaries()
            print("📍 Fetched responses:", responses)
            
            await MainActor.run {
                self.diaryEntries = responses
                    .sorted { 
                        // date 기준으로 정렬
                        $0.date > $1.date 
                    }
                    .prefix(5)
                    .map { response in
                        DiaryEntry(
                            id: response.id,
                            date: formatDate(from: response.date),
                            images: response.images,  // image_urls 대신 images 사용
                            text: response.text ?? ""
                        )
                    }
                isLoading = false
            }
        } catch {
            print("❌ Error fetching diaries:", error)
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func formatDate(from dateString: String) -> String {
        // ISO 8601 형식의 문자열을 파싱하기 위한 DateFormatter
        let inputFormatter = ISO8601DateFormatter()
        
        // 출력을 위한 DateFormatter
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ko_KR")
        outputFormatter.dateFormat = "yyyy년 M월 d일"
        
        // ISO 8601 문자열을 Date 객체로 변환
        if let date = inputFormatter.date(from: dateString) {
            return outputFormatter.string(from: date)
        }
        
        // ISO 8601 파싱에 실패한 경우, 간단한 문자열 슬라이싱 사용
        let components = dateString.split(separator: "T")
        if let dateComponent = components.first {
            let dateParts = dateComponent.split(separator: "-")
            if dateParts.count == 3,
               let year = dateParts[safe: 0],
               let month = dateParts[safe: 1],
               let day = dateParts[safe: 2] {
                return "\(year)년 \(Int(month) ?? 0)월 \(Int(day) ?? 0)일"
            }
        }
        
        return dateString // 모든 파싱이 실패한 경우 원본 문자열 반환
    }
    
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM dd"
        return formatter.string(from: Date())
    }
    
    private func loadTransferable(from items: [PhotosPickerItem]) {
        Task {
            selectedImages.removeAll() // 기존 이미지 초기화
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                    let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(image)
                    }
                }
            }
            
            await MainActor.run {
                if !selectedImages.isEmpty {
                    showWriteLogView = true
                }
                selectedItems.removeAll() // 선택 초기화
            }
        }
    }
    
    private func shouldShowRefreshIndicator(_ geometry: GeometryProxy) -> Bool {
        let frame = geometry.frame(in: .global)
        // 스크롤이 오른쪽 끝을 넘어갈 때 새로고침 표시
        return frame.minX < -20 // 오른쪽으로 스크롤할 때 음수값이 커짐
    }
}

// ✅ 다이어리 카드 뷰
struct DiaryCardView: View {
    let entry: DiaryEntry
    
    var body: some View {
        VStack {
            if !entry.imageUrl.isEmpty {
                AsyncImage(url: URL(string: entry.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(let error):
                        Color.gray
                            .onAppear {
                                print("❌ Image loading failed for URL:", entry.imageUrl)
                                print("❌ Error:", error)
                            }
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(width: 200, height: 300)
                .cornerRadius(15)
                .onAppear {
                    print("📍 Trying to load image from URL:", entry.imageUrl)
                }
            } else {
                Color.gray
                    .frame(width: 200, height: 300)
                    .cornerRadius(15)
                    .onAppear {
                        print("⚠️ No image available")
                    }
            }
            
            Text(entry.date)
                .font(.headline)
                .foregroundColor(.white)
//                .padding(.top, 8)
        }
    }
}

// ✅ 다이어리 상세 뷰
struct DiaryDetailView: View {
    let entry: DiaryEntry
    
    var body: some View {
        VStack {
            AsyncImage(url: URL(string: entry.imageUrl)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray
            }
            Text(entry.text)
                .font(.title)
                .foregroundColor(.white)
                .padding()
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// ✅ 다이어리 데이터 모델
struct DiaryEntry: Identifiable {
    let id: String
    let date: String
    let images: [ImageInfo]  // image_urls 대신 images 배열 사용
    let text: String
    
    // 첫 번째 이미지 URL을 반환하는 계산 프로퍼티
    var imageUrl: String {
        guard let firstImage = images.first else { return "" }
        return firstImage.image_url
    }
}

// 메인 뷰 선택을 위한 열거형
enum MainViewSelection {
    case main
    case archive
}

// 안전한 배열 접근을 위한 extension
extension Array {   
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MainView 내부에 LoadingView 구조체 추가
struct LoadingView: View {
    let diaryId: String
    @State private var diaryResponse: DiaryResponse?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let diaryResponse = diaryResponse {
                SavedLogView(diaryResponse: diaryResponse, isFromWriteView: false)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .task {
            do {
                diaryResponse = try await DiaryService.shared.getDiary(id: diaryId)
            } catch {
                print("Error loading diary:", error)
            }
            isLoading = false
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AuthService())
}
