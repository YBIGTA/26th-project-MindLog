import SwiftUI

struct ArchiveMainView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var showRecentLogs = false
    @State private var showFeelingView = false
    @State private var showMapView = false
    @State private var showCompanionView = false
    @State private var showHighlightView = false
    @State private var showLogoutAlert = false
    @State private var dominantEmotion: String?
    @State private var diaryActivities: [DiaryActivity] = []
    
    // 감정별 색상 매핑
    private let emotionColors: [String: String] = [
        "기쁨": "#FFD700",
        "신뢰": "#4A90E2", 
        "긴장": "#4A4A4A",
        "놀람": "#FF9F1C",
        "슬픔": "#5C85D6",
        "혐오": "#6B8E23",
        "격노": "#E63946",
        "열망": "#9B59B6"
    ]
    
    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                // ✅ 상단 헤딩
                HStack {
                    Heading(title: "Archive", buttonIcon: "chevron.down", menuItems: [
                        MenuItem(title: "MindLog.", isSelected: false, action: {
                            dismiss()
                        }),
                        MenuItem(title: "Archive", isSelected: true, action: {}),
                        MenuItem(title: "", isSelected: false, isDivider: true) {},
                        MenuItem(title: "Logout", isSelected: false, action: {
                            showLogoutAlert = true
                        })
                    ])
                    .padding(-10) // MainView와 동일하게 화면 너비의 5%
                    
                    Spacer()
                }
                .padding(.top, UIScreen.main.bounds.height * 0.035) // MainView와 동일하게 화면 높이의 3%
                
                // Heatmap CalendarBox 호출 - activities 전달
                HeatmapBox(action: {
                    showRecentLogs = true
                }, activities: diaryActivities)
                .padding(.top, UIScreen.main.bounds.height * 0.02)
                
                // MenuBox 호출
                HStack(spacing: 12) {
                    MenuBox(title: "Feeling",
                           imageName: "calendarImage",
                           textColor: Color(hex: "#ffffff"),
                           backgroundColor: Color(hex: emotionColors[dominantEmotion ?? ""] ?? "#6b8e23")) {
                        showFeelingView = true
                    }
                    .zIndex(1)
                    
                    MenuBox(title: "Place", 
                           imageName: "place",
                           textColor: Color(hex: "#ffffff"),
                           backgroundColor: Color(hex: "#ffffff")) {
                        showMapView = true
                    }
                        .zIndex(2)
                }

                
                HStack(spacing: 12) {
                    MenuBox(title: "Companion", 
                           imageName: "companion",
                           textColor: Color(hex: "#ffffff"),
                           backgroundColor: Color(hex: "#ffffff")) {
                        showCompanionView = true
                    }
                        .zIndex(3)
                    
                    MenuBox(title: "Highlights", 
                           imageName: "highlight",
                           textColor: Color(hex: "#ffffff"),
                           backgroundColor: Color(hex: "#ffffff")) {
                        showHighlightView = true
                    }
                        .zIndex(4)
                }
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .commonBackground()
        .fullScreenCover(isPresented: $showRecentLogs) {
            ArchiveRecentLogView()
        }
        .fullScreenCover(isPresented: $showFeelingView) {
            ArchiveFeelingView()
        }
        .fullScreenCover(isPresented: $showMapView) {
            ArchiveMapView()
        }
        .fullScreenCover(isPresented: $showCompanionView) {
            ArchiveCompanionView()
        }
        .fullScreenCover(isPresented: $showHighlightView) {
            StoryPopupView(isPresented: $showHighlightView)
        }
        .alert("로그아웃", isPresented: $showLogoutAlert) {
            Button("취소", role: .cancel) { }
            Button("확인", role: .destructive) {
                authService.logout()
            }
        } message: {
            Text("로그아웃하시겠습니까?")
        }
        .task {
            await fetchDominantEmotion()
            await fetchRecentActivities()
        }
    }
    
    private func fetchDominantEmotion() async {
        do {
            let currentYear = Calendar.current.component(.year, from: Date())
            let response = try await DiaryService.shared.getDominantEmotion(year: currentYear)
            await MainActor.run {
                print("Received dominant emotion:", response.emotion) // 디버깅용
                dominantEmotion = response.emotion
            }
        } catch {
            print("Error fetching dominant emotion:", error)
        }
    }
    
    private func fetchRecentActivities() async {
        do {
            let activities = try await DiaryService.shared.getRecentActivities()
            await MainActor.run {
                self.diaryActivities = activities
                print("Received activities:", activities) // 디버깅용
            }
        } catch {
            print("Error fetching recent activities:", error)
        }
    }
}

// Preview
struct ArchiveMainView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveMainView()
    }
}
