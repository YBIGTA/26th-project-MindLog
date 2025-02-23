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
                        MenuItem(title: "Logout", isSelected: false, action: {
                            showLogoutAlert = true
                        })
                    ])
                    .padding(-10) // MainView와 동일하게 화면 너비의 5%
                    
                    Spacer()
                }
                .padding(.top, UIScreen.main.bounds.height * 0.035) // MainView와 동일하게 화면 높이의 3%
                
                // Heatmap CalendarBox 호출
                HeatmapBox(action: {
                    showRecentLogs = true
                })
                .padding(.top, UIScreen.main.bounds.height * 0.02) // 상단 여백 추가
                
                // MenuBox 호출
                HStack(spacing: 12) {
                    MenuBox(title: "Feeling",
                           imageName: "calendarImage",
                           textColor: Color(hex: "#ffffff"),
                           backgroundColor: Color(hex: "#6b8e23")) {
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
    }
}

// Preview
struct ArchiveMainView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveMainView()
    }
}
